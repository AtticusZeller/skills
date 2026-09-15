#!/usr/bin/env bash
# Regression test for delegate-worker.sh, using a stub cc-switch (no provider calls).
#
# Verifies:
#   1. the worker contract asset is deployed byte-for-byte into the system prompt;
#   2. new / resume / fork pass the right session, permission, and isolation flags;
#   3. state is recorded per round and never silently overwritten;
#   4. worker errors and timeouts surface as exit code 2.
#
# Usage: bash test-delegate-worker.sh

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="$here/delegate-worker.sh"
contract="$here/../assets/worker-contract.md"

fails=0
pass() { printf '  PASS  %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
check() { if eval "$2"; then pass "$1"; else fail "$1"; fi; }

echo "test-delegate-worker.sh"
echo

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/repo" "$tmp/log"
printf '# Repo rules\n\nNever touch secrets/.\n' >"$tmp/repo/AGENTS.md"
mkdir -p "$tmp/repo-claude"
printf '# Agent rules\n\nUse tabs.\n' >"$tmp/repo-claude/AGENTS.md"
printf '@AGENTS.md\n' >"$tmp/repo-claude/CLAUDE.md"
printf -- '- starts with a dash\nsecond line\n' >"$tmp/brief.md"

cat >"$tmp/cc-switch" <<'STUB'
#!/usr/bin/env bash
n=$(( $(find "$STUB_LOG_DIR" -name '*.args' | wc -l) + 1 ))
printf '%s\n' "$@" >"$STUB_LOG_DIR/$n.args"
pwd >"$STUB_LOG_DIR/$n.cwd"
cat >"$STUB_LOG_DIR/$n.stdin"
sid="" fork=0 prev=""
for a in "$@"; do
  case "$prev" in --session-id | --resume) sid="$a" ;; esac
  [[ "$a" == --fork-session ]] && fork=1
  prev="$a"
done
((fork)) && sid="fork-$sid"
[[ -n "${STUB_SLEEP:-}" ]] && exec sleep "$STUB_SLEEP"
printf '{"type":"result","is_error":%s,"num_turns":3,"duration_ms":1200,"session_id":"%s","result":"stub report","permission_denials":[{"tool_name":"Bash","tool_input":{"command":"mkdir a && cp b c"}}]}\n' \
  "${STUB_ERROR:-false}" "$sid"
STUB
chmod +x "$tmp/cc-switch"

export DELEGATE_WORKER_HOME="$tmp/state" DELEGATE_WORKER_CC_SWITCH="$tmp/cc-switch" STUB_LOG_DIR="$tmp/log"
run() { "$script" "$@" >"$tmp/out" 2>&1; echo $?; }
has_arg() { grep -Fxq -- "$2" "$tmp/log/$1.args"; }
# allowed/denied print the rule list that follows --allowedTools / --disallowedTools.
allowed() { sed -n '/^--allowedTools$/,/^--disallowedTools$/p' "$tmp/log/$1.args" | grep -Fxq -- "$2"; }
denied() { sed -n '/^--disallowedTools$/,$p' "$tmp/log/$1.args" | grep -Fxq -- "$2"; }
meta() { jq -r "$2" "$tmp/state/$1/meta.json"; }

# ── 1. Script basics ─────────────────────────────────────────────────────────
check "script is executable" '[[ -x "$script" ]]'
check "syntax valid" 'bash -n "$script"'
check "contract asset exists" '[[ -s "$contract" ]]'

# ── 2. new (readonly, inheriting) ────────────────────────────────────────────
rc="$(run new repo-overview --provider deepseek --cwd "$tmp/repo" --brief "$tmp/brief.md")"
check "new exits 0" '[[ "$rc" == 0 ]]'
check "new launches the provider through cc-switch" \
  '[[ "$(sed -n 1,4p "$tmp/log/1.args" | paste -sd " ")" == "start claude deepseek --" ]]'
check "new runs in the worker cwd" '[[ "$(cat "$tmp/log/1.cwd")" == "$tmp/repo" ]]'
check "brief is passed on stdin unchanged" 'cmp -s "$tmp/brief.md" "$tmp/log/1.stdin"'
check "new inherits the caller's setup (no --bare)" '! has_arg 1 --bare'
check "new pins the session id" 'has_arg 1 --session-id && has_arg 1 "$(meta repo-overview .session_id)"'
check "readonly allows Read and denies Edit and Write" \
  'allowed 1 Read && denied 1 Edit && denied 1 Write && ! allowed 1 Write'
check "readonly allows inherited skills and deferred tools" 'allowed 1 Skill && allowed 1 ToolSearch'
check "json output requested" 'has_arg 1 json'
sp="$tmp/state/repo-overview/system-prompt.md"
check "contract deployed byte-for-byte" 'cmp -s <(head -c "$(wc -c <"$contract")" "$sp") "$contract"'
check "AGENTS.md appended when the repo has no CLAUDE.md" 'grep -Fq "Never touch secrets/." "$sp"'
check "round 1 recorded with denials" \
  '[[ "$(meta repo-overview ".rounds | length")" == 1 && "$(meta repo-overview ".rounds[0].denials | length")" == 1 ]]'
check "report printed" 'grep -Fq "stub report" "$tmp/out" && grep -Fq "status: ok" "$tmp/out"'

# ── 3. no silent overwrite ───────────────────────────────────────────────────
rc="$(run new repo-overview --provider deepseek --cwd "$tmp/repo" --message hi)"
check "new refuses an existing worker" '[[ "$rc" == 1 && "$(meta repo-overview ".rounds | length")" == 1 ]]'
rc="$(run new Bad_Name --provider deepseek --cwd "$tmp/repo" --message hi)"
check "invalid name rejected" '[[ "$rc" == 1 && ! -e "$tmp/state/Bad_Name" ]]'
rc="$(run new no-prompt --provider deepseek --cwd "$tmp/repo")"
check "missing prompt rejected before state is created" '[[ "$rc" == 1 && ! -e "$tmp/state/no-prompt" ]]'

# ── 4. resume ────────────────────────────────────────────────────────────────
sid="$(meta repo-overview .session_id)"
rc="$(run resume repo-overview --message "Q1: yes" --allow "Bash(make:*)")"
check "resume exits 0" '[[ "$rc" == 0 ]]'
check "resume reuses the session" 'has_arg 2 --resume && has_arg 2 "$sid" && ! has_arg 2 --session-id'
check "resume message delivered on stdin" '[[ "$(cat "$tmp/log/2.stdin")" == "Q1: yes" ]]'
check "extra allow rule applied" 'has_arg 2 "Bash(make:*)"'
rc="$(run resume repo-overview --message again)"
check "extra allow rule persists across rounds" 'has_arg 3 "Bash(make:*)"'
check "rounds and turns accumulate" \
  '[[ "$(meta repo-overview ".rounds | length")" == 3 && "$(meta repo-overview .total_turns)" == 9 ]]'
rc="$(run resume repo-overview --message x --profile edit)"
check "resume refuses to change the profile" '[[ "$rc" == 1 ]]'

# ── 5. fork ──────────────────────────────────────────────────────────────────
rc="$(run fork repo-overview repo-overview-alt --message "try B")"
check "fork exits 0" '[[ "$rc" == 0 ]]'
check "fork resumes the source with --fork-session" 'has_arg 4 --fork-session && has_arg 4 "$sid"'
check "fork records its own session and parent" \
  '[[ "$(meta repo-overview-alt .session_id)" == "fork-$sid" && "$(meta repo-overview-alt .parent)" == repo-overview ]]'
check "fork leaves the source unchanged" \
  '[[ "$(meta repo-overview .session_id)" == "$sid" && "$(meta repo-overview ".rounds | length")" == 3 ]]'

# ── 6. edit profile, bare, CLAUDE.md discovery ───────────────────────────────
rc="$(run new repo-edit --provider deepseek --cwd "$tmp/repo-claude" --profile edit --bare --message go)"
check "edit profile allows Write and Edit" 'allowed 5 Write && allowed 5 Edit && ! denied 5 Write'
check "edit profile denies agent config writes and commits" \
  'denied 5 "Edit(~/.claude/**)" && denied 5 "Bash(git commit:*)" && denied 5 "Bash(rm:*)"'
check "--bare is passed through" 'has_arg 5 --bare'
check "--bare inlines AGENTS.md even when CLAUDE.md exists" \
  'grep -Fq "Use tabs." "$tmp/state/repo-edit/system-prompt.md"'
rc="$(run resume repo-edit --message x --bare)"
check "resume refuses to change isolation" '[[ "$rc" == 1 ]]'
rc="$(run new repo-native --provider deepseek --cwd "$tmp/repo-claude" --message go)"
check "CLAUDE.md repo is left to native discovery" \
  '! has_arg 6 --bare && cmp -s "$contract" "$tmp/state/repo-native/system-prompt.md"'

# ── 7. failures ──────────────────────────────────────────────────────────────
rc="$(STUB_ERROR=true run new repo-error --provider deepseek --cwd "$tmp/repo" --message go)"
check "worker error exits 2" '[[ "$rc" == 2 && "$(meta repo-error .status)" == error ]]'
rc="$(STUB_SLEEP=5 run new repo-slow --provider deepseek --cwd "$tmp/repo" --timeout 1 --message go)"
check "timeout exits 2" '[[ "$rc" == 2 && "$(meta repo-slow .status)" == timeout ]]'

# ── 8. list and show ─────────────────────────────────────────────────────────
rc="$(run list)"
check "list shows workers" 'grep -q "^repo-overview	deepseek	readonly	rounds=3" "$tmp/out"'
rc="$(run show repo-overview --round 2)"
check "show prints a chosen round" '[[ "$rc" == 0 ]] && grep -Fq "round:    2 (resume)" "$tmp/out"'
rc="$(run show repo-overview --round 9)"
check "show rejects an out-of-range round" '[[ "$rc" == 1 ]]'

echo
if ((fails)); then
  echo "FAILED: $fails check(s)"
  exit 1
fi
echo "All checks passed."
