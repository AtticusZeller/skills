#!/usr/bin/env bash
# delegate-worker.sh — run a Claude Code worker on a cc-switch provider and keep its session.
#
# Usage:
#   delegate-worker.sh new <name> --provider P --cwd DIR [--profile readonly|edit]
#                          (--brief FILE | --message TEXT) [--allow RULE]... [--timeout SEC] [--bare]
#   delegate-worker.sh resume <name> (--brief FILE | --message TEXT) [--allow RULE]... [--timeout SEC]
#   delegate-worker.sh fork <name> <new-name> (--brief FILE | --message TEXT) [--allow RULE]... [--timeout SEC]
#   delegate-worker.sh list
#   delegate-worker.sh show <name> [--round N]
#
# Environment:
#   DELEGATE_WORKER_HOME       state root (default: ${XDG_STATE_HOME:-~/.local/state}/delegate-worker)
#   DELEGATE_WORKER_CC_SWITCH  cc-switch executable (default: cc-switch)
#
# Exit codes: 0 round finished ok, 1 usage or state error, 2 worker failed or timed out.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
contract="$here/../assets/worker-contract.md"
state_root="${DELEGATE_WORKER_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/delegate-worker}"
cc_switch="${DELEGATE_WORKER_CC_SWITCH:-cc-switch}"

readonly_allow=(Read Glob Grep Skill ToolSearch "Bash(ls:*)" "Bash(wc:*)" "Bash(rg:*)"
  "Bash(git status:*)" "Bash(git log:*)" "Bash(git diff:*)" "Bash(git show:*)")
readonly_deny=(Edit Write NotebookEdit)
edit_allow=("${readonly_allow[@]}" Edit Write
  "Bash(mkdir:*)" "Bash(cp:*)" "Bash(mv:*)" "Bash(touch:*)" "Bash(diff:*)" "Bash(cmp:*)")
edit_deny=("Edit(~/.claude/**)" "Edit(~/.codex/**)" "Bash(rm:*)"
  "Bash(git add:*)" "Bash(git commit:*)" "Bash(git push:*)"
  "Bash(git reset:*)" "Bash(git checkout:*)" "Bash(git restore:*)")

usage() { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
die() { echo "ERROR: $*" >&2; exit 1; }

for dep in jq timeout; do
  command -v "$dep" >/dev/null 2>&1 || die "missing dependency: $dep"
done

provider="" cwd="" profile="" brief="" message="" timeout_s=900 bare=0 show_round=""
extra_allow=()

parse_opts() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --provider) provider="${2:?--provider needs a value}"; shift 2 ;;
      --cwd) cwd="${2:?--cwd needs a value}"; shift 2 ;;
      --profile) profile="${2:?--profile needs a value}"; shift 2 ;;
      --brief) brief="${2:?--brief needs a file}"; shift 2 ;;
      --message) message="${2:?--message needs text}"; shift 2 ;;
      --allow) extra_allow+=("${2:?--allow needs a rule}"); shift 2 ;;
      --timeout) timeout_s="${2:?--timeout needs seconds}"; shift 2 ;;
      --round) show_round="${2:?--round needs a number}"; shift 2 ;;
      --bare) bare=1; shift ;;
      -h | --help) usage ;;
      *) die "unknown option: $1" ;;
    esac
  done
  [[ "$timeout_s" =~ ^[0-9]+$ ]] || die "--timeout must be whole seconds"
}

valid_name() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9-]{0,63}$ ]] || die "invalid worker name '$1' (lowercase letters, digits, hyphens)"
}

require_prompt() {
  [[ -n "$brief" && -n "$message" ]] && die "use either --brief or --message, not both"
  [[ -z "$brief" && -z "$message" ]] && die "--brief FILE or --message TEXT is required"
  [[ -z "$brief" || -f "$brief" ]] || die "brief not found: $brief"
}

reject_session_opts() {
  [[ -z "$provider" && -z "$cwd" && -z "$profile" && "$bare" == 0 ]] ||
    die "--provider, --cwd, --profile and --bare are fixed when a worker is created"
}

new_uuid() { uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid; }

worker_dir() {
  valid_name "$1"
  printf '%s/%s' "$state_root" "$1"
}

# Claude Code discovers CLAUDE.md but never AGENTS.md, and --bare discovers neither.
# Inline the repository rules that the worker would otherwise miss.
build_system_prompt() {
  local dir="$1" use_bare="$2" rules=""
  cat "$contract"
  if [[ "$use_bare" == 1 ]]; then
    for rules in AGENTS.md CLAUDE.md ""; do
      [[ -n "$rules" && -f "$dir/$rules" ]] && break
    done
  elif [[ -f "$dir/AGENTS.md" && ! -f "$dir/CLAUDE.md" ]]; then
    rules=AGENTS.md
  fi
  if [[ -n "$rules" && -f "$dir/$rules" ]]; then
    printf '\n---\n\n# Repository rules: %s\n\n' "$rules"
    cat "$dir/$rules"
  fi
}

# run_round <worker-dir> <mode> <session args...>
run_round() {
  local dir="$1" mode="$2"
  shift 2
  local meta="$dir/meta.json"
  local n tag
  n=$(($(jq '.rounds | length' "$meta") + 1))
  tag="$(printf '%03d' "$n")"
  mkdir -p "$dir/rounds"

  local brief_file="$dir/rounds/$tag.brief.md"
  if [[ -n "$brief" ]]; then cat "$brief" >"$brief_file"; else printf '%s\n' "$message" >"$brief_file"; fi

  if ((${#extra_allow[@]})); then
    jq --args '.extra_allow = ((.extra_allow + $ARGS.positional) | unique)' "${extra_allow[@]}" \
      <"$meta" >"$meta.tmp" && mv "$meta.tmp" "$meta"
  fi

  local wcwd wprovider wprofile wbare
  wcwd="$(jq -r .cwd "$meta")"
  wprovider="$(jq -r .provider "$meta")"
  wprofile="$(jq -r .profile "$meta")"
  wbare="$(jq -r .bare "$meta")"
  [[ -d "$wcwd" ]] || die "worker cwd no longer exists: $wcwd"

  local allow=() deny=() stored=()
  if [[ "$wprofile" == edit ]]; then allow=("${edit_allow[@]}") deny=("${edit_deny[@]}")
  else allow=("${readonly_allow[@]}") deny=("${readonly_deny[@]}"); fi
  mapfile -t stored < <(jq -r '.extra_allow[]' "$meta")
  ((${#stored[@]})) && allow+=("${stored[@]}")

  local args=()
  [[ "$wbare" == true ]] && args+=(--bare)
  args+=(-p "$@" --output-format json
    --append-system-prompt-file "$dir/system-prompt.md"
    --allowedTools "${allow[@]}" --disallowedTools "${deny[@]}")

  local result="$dir/rounds/$tag.result.json" stderr_log="$dir/rounds/$tag.stderr.log"
  local rc=0
  (cd "$wcwd" && timeout "$timeout_s" "$cc_switch" start claude "$wprovider" -- "${args[@]}" <"$brief_file") \
    >"$result" 2>"$stderr_log" || rc=$?

  local status summary='{}'
  if jq -e 'type == "object" and has("result")' "$result" >/dev/null 2>&1; then
    summary="$(jq -c '{is_error, num_turns, duration_ms, session_id,
      denials: [(.permission_denials // [])[]
        | "\(.tool_name): \((.tool_input.command // .tool_input.file_path // .tool_input) | tostring | .[0:160])"]}' "$result")"
    if [[ "$(jq -r .is_error <<<"$summary")" == true ]]; then status=error; else status=ok; fi
  else
    status=error
  fi
  ((rc == 124)) && status=timeout
  [[ "$status" == ok && "$rc" != 0 ]] && status=error

  jq --argjson s "$summary" --arg mode "$mode" --arg status "$status" --argjson rc "$rc" \
    --arg at "$(date -Iseconds)" --arg brief "rounds/$tag.brief.md" --arg res "rounds/$tag.result.json" '
    .session_id = ($s.session_id // .session_id)
    | .status = $status
    | .updated_at = $at
    | .rounds += [{round: ((.rounds | length) + 1), mode: $mode, at: $at, status: $status,
        exit_code: $rc, brief: $brief, result: $res,
        num_turns: $s.num_turns, duration_ms: $s.duration_ms, denials: ($s.denials // [])}]
    | .total_turns = ([.rounds[].num_turns // 0] | add)' \
    <"$meta" >"$meta.tmp" && mv "$meta.tmp" "$meta"

  print_round "$dir" "$n"
  [[ "$status" == ok ]] || exit 2
}

print_round() {
  local dir="$1" n="$2"
  local meta="$dir/meta.json"
  jq -r --argjson n "$n" '.rounds[$n - 1] as $r
    | "worker:   \(.name)\(if .parent then "  (forked from \(.parent))" else "" end)",
      "provider: \(.provider)  profile: \(.profile)  bare: \(.bare)",
      "cwd:      \(.cwd)",
      "session:  \(.session_id)",
      "round:    \($r.round) (\($r.mode))  status: \($r.status)  turns: \($r.num_turns)  duration_ms: \($r.duration_ms)",
      "denials:  \($r.denials | length)",
      ($r.denials[] | "  - " + .),
      "state:    \(input_filename | sub("/meta.json$"; ""))"' "$meta"
  local tag result stderr_log
  tag="$(printf '%03d' "$n")"
  result="$dir/rounds/$tag.result.json"
  stderr_log="$dir/rounds/$tag.stderr.log"
  echo "--- result ---"
  jq -r '.result // empty' "$result" 2>/dev/null || true
  if [[ "$(jq -r --argjson n "$n" '.rounds[$n - 1].status' "$meta")" != ok && -s "$stderr_log" ]]; then
    echo "--- stderr (tail) ---"
    tail -n 30 "$stderr_log"
  fi
}

cmd_new() {
  local name="${1:-}"
  [[ -n "$name" ]] || usage 1
  shift
  local dir
  dir="$(worker_dir "$name")"
  parse_opts "$@"
  require_prompt
  [[ -n "$provider" ]] || die "--provider is required"
  [[ -n "$cwd" ]] || die "--cwd is required"
  [[ -d "$cwd" ]] || die "cwd not found: $cwd"
  profile="${profile:-readonly}"
  [[ "$profile" == readonly || "$profile" == edit ]] || die "unknown profile: $profile"
  [[ ! -e "$dir" ]] || die "worker already exists: $name (resume or fork it, or choose another name)"

  cwd="$(cd "$cwd" && pwd)"
  mkdir -p "$dir/rounds"
  build_system_prompt "$cwd" "$bare" >"$dir/system-prompt.md"
  local sid
  sid="$(new_uuid)"
  jq -n --arg name "$name" --arg provider "$provider" --arg cwd "$cwd" --arg profile "$profile" \
    --argjson bare "$([[ "$bare" == 1 ]] && echo true || echo false)" --arg sid "$sid" \
    --arg at "$(date -Iseconds)" '
    {name: $name, parent: null, provider: $provider, cwd: $cwd, profile: $profile, bare: $bare,
     session_id: $sid, extra_allow: [], status: "new", created_at: $at, updated_at: $at,
     total_turns: 0, rounds: []}' >"$dir/meta.json"
  run_round "$dir" new --session-id "$sid"
}

cmd_resume() {
  local name="${1:-}"
  [[ -n "$name" ]] || usage 1
  shift
  local dir
  dir="$(worker_dir "$name")"
  parse_opts "$@"
  reject_session_opts
  require_prompt
  [[ -f "$dir/meta.json" ]] || die "no such worker: $name"
  run_round "$dir" resume --resume "$(jq -r .session_id "$dir/meta.json")"
}

cmd_fork() {
  local name="${1:-}" new_name="${2:-}"
  [[ -n "$name" && -n "$new_name" ]] || usage 1
  shift 2
  local src dst
  src="$(worker_dir "$name")"
  dst="$(worker_dir "$new_name")"
  parse_opts "$@"
  reject_session_opts
  require_prompt
  [[ -f "$src/meta.json" ]] || die "no such worker: $name"
  [[ ! -e "$dst" ]] || die "worker already exists: $new_name"
  mkdir -p "$dst/rounds"
  cp "$src/system-prompt.md" "$dst/system-prompt.md"
  jq --arg name "$new_name" --arg parent "$name" --arg at "$(date -Iseconds)" '
    .name = $name | .parent = $parent | .status = "new" | .created_at = $at | .updated_at = $at
    | .total_turns = 0 | .rounds = []' <"$src/meta.json" >"$dst/meta.json"
  run_round "$dst" fork --resume "$(jq -r .session_id "$src/meta.json")" --fork-session
}

cmd_list() {
  local found=0 meta
  for meta in "$state_root"/*/meta.json; do
    [[ -f "$meta" ]] || continue
    found=1
    jq -r '[.name, .provider, .profile, "rounds=\(.rounds | length)", "turns=\(.total_turns)",
      .status, .updated_at, .cwd] | @tsv' "$meta"
  done
  ((found)) || echo "(no workers under $state_root)"
}

cmd_show() {
  local name="${1:-}"
  [[ -n "$name" ]] || usage 1
  shift
  local dir
  dir="$(worker_dir "$name")"
  parse_opts "$@"
  [[ -f "$dir/meta.json" ]] || die "no such worker: $name"
  local count
  count="$(jq '.rounds | length' "$dir/meta.json")"
  ((count > 0)) || die "worker $name has no rounds"
  local n="${show_round:-$count}"
  [[ "$n" =~ ^[0-9]+$ ]] && ((n >= 1 && n <= count)) || die "round must be between 1 and $count"
  print_round "$dir" "$n"
}

case "${1:-}" in
  new) shift; cmd_new "$@" ;;
  resume) shift; cmd_resume "$@" ;;
  fork) shift; cmd_fork "$@" ;;
  list) cmd_list ;;
  show) shift; cmd_show "$@" ;;
  -h | --help | "") usage ;;
  *) die "unknown command: $1" ;;
esac
