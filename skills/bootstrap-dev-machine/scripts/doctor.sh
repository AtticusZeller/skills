#!/usr/bin/env bash
# Read-only report of how this machine differs from the skills repository baseline.
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: doctor.sh [options]

Report packages, third-party skills, personal skills and configs against the
skills repository. Read-only unless --sync or --ignore is given.

Options:
  --repo <dir>          Skills repository checkout (default: see below)
  --skip-packages       Skip the package check (check-dev-machine.sh)
  --verbose             Print the full package check output
  --diff <id>           Show the difference for one item (template vs local)
  --sync <id> --to local|repo
                        Copy one exact-type item: repo asset -> machine (local),
                        or machine -> repo asset (repo). Backs up the target.
  --ignore <id>         Add an item to the ignore list and exit
  -h, --help            Show this help

Repository lookup: --repo, $PERSONAL_SKILLS_DIR, the checkout containing this
script, the local source recorded in ~/.agents/.skill-lock.json, then ~/skills.
Ignore list: ${XDG_CONFIG_HOME:-~/.config}/bootstrap-dev-machine/doctor-ignore
Exit status: 0 when clean, 1 when any item is MISSING, DRIFT, STALE, SOURCE or WARN.
EOF
}

repo=""
skip_packages=false
verbose=false
diff_id=""
sync_id=""
sync_to=""
ignore_id=""
while (($#)); do
  case "$1" in
    --repo|--diff|--sync|--to|--ignore)
      (($# >= 2)) || { echo "$1 requires a value" >&2; exit 2; }
      case "$1" in
        --repo) repo="$2" ;;
        --diff) diff_id="$2" ;;
        --sync) sync_id="$2" ;;
        --to) sync_to="$2" ;;
        --ignore) ignore_id="$2" ;;
      esac
      shift 2
      ;;
    --skip-packages) skip_packages=true; shift ;;
    --verbose) verbose=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

[[ -z "${sync_to}" || -n "${sync_id}" ]] || { echo "--to is only valid with --sync" >&2; exit 2; }
ignore_file="${XDG_CONFIG_HOME:-${HOME}/.config}/bootstrap-dev-machine/doctor-ignore"
if [[ -n "${ignore_id}" ]]; then
  mkdir -p "$(dirname "${ignore_file}")"
  grep -Fxq -- "${ignore_id}" "${ignore_file}" 2>/dev/null || printf '%s\n' "${ignore_id}" >>"${ignore_file}"
  echo "[INFO] ${ignore_id} ignored via ${ignore_file}"
  exit 0
fi

# ── Locate the repository checkout ───────────────────────────────────────────
# A git worktree has a .git file rather than a directory.
is_checkout() { [[ -n "$1" && -e "$1/.git" && -d "$1/skills/bootstrap-dev-machine" ]]; }
lock_file="${HOME}/.agents/.skill-lock.json"
lock_source=""
if command -v jq >/dev/null 2>&1 && [[ -f "${lock_file}" ]]; then
  lock_source="$(jq -r '.skills["bootstrap-dev-machine"] | select(.sourceType == "local") | .source // empty' "${lock_file}" 2>/dev/null)"
fi
if [[ -z "${repo}" ]]; then
  for candidate in "${PERSONAL_SKILLS_DIR:-}" "$(cd "${script_dir}/../../.." && pwd)" "${lock_source}" "${HOME}/skills"; do
    if is_checkout "${candidate}"; then repo="${candidate}"; break; fi
  done
elif ! is_checkout "${repo}"; then
  echo "Not a skills repository checkout: ${repo}" >&2
  exit 2
fi
if [[ -n "${repo}" ]]; then
  repo="$(cd "${repo}" && pwd)"
  skill_dir="${repo}/skills/bootstrap-dev-machine"
else
  skill_dir="$(cd "${script_dir}/.." && pwd)"
fi
asset_dir="${skill_dir}/assets"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

# ── Config items: id|type|template|local ─────────────────────────────────────
#  exact     byte-identical (JSON value for statusline-setting)
#  prefix    template's non-blank, non-comment lines are a prefix of the local file's
#  contains  template's effective lines appear in order anywhere in the local file
#  sections  every template "##" section (and the preamble) appears unchanged locally;
#            extra local sections are allowed anywhere
claude_dir="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"
xdg="${XDG_CONFIG_HOME:-${HOME}/.config}"
render_dir="${tmp_dir}/render"
items=(
  "statusline-script|exact|${asset_dir}/claude-statusline.sh|${claude_dir}/statusline-command.sh"
  "statusline-setting|exact-json|${tmp_dir}/statusline.json|${claude_dir}/settings.json"
  "herdr|exact|${asset_dir}/herdr-config.toml|${xdg}/herdr/config.toml"
  "p10k|exact|${asset_dir}/p10k.zsh|${HOME}/.p10k.zsh"
  "ghostty|prefix|${asset_dir}/ghostty-config.ghostty|${xdg}/ghostty/config.ghostty"
  "tmux-local|contains|${asset_dir}/tmux-defaults.conf|${xdg}/tmux/tmux.conf.local"
  "zshrc|prefix|${asset_dir}/zshrc.server|${HOME}/.zshrc"
  "codex-agents|sections|${render_dir}/.codex/AGENTS.md|${HOME}/.codex/AGENTS.md"
)

prepare_templates() {
  mkdir -p "${render_dir}"
  bash "${skill_dir}/scripts/install-machine-handoff.sh" --target-home "${render_dir}" >/dev/null 2>&1 ||
    echo "[WARN] Could not render handoff templates" >&2
  if [[ -x "${skill_dir}/scripts/install-claude-statusline.sh" ]] && command -v jq >/dev/null 2>&1; then
    # An empty or failed result must read as "template missing", never as an empty value.
    bash "${skill_dir}/scripts/install-claude-statusline.sh" --print-setting >"${tmp_dir}/statusline.json" 2>/dev/null &&
      jq -e 'type == "object"' "${tmp_dir}/statusline.json" >/dev/null 2>&1 ||
      rm -f "${tmp_dir}/statusline.json"
  fi
}

effective_lines() { grep -Ev '^[[:space:]]*(#|$)' "$1" || true; }

# Split Markdown into numbered section files plus an index of "N<TAB>heading".
split_sections() {   # file outdir
  mkdir -p "$2"
  awk -v out="$2" '
    function flush() { if (n >= 0) close(out "/" n) }
    BEGIN { n = 0; print n "\t(preamble)" > (out "/index"); fence = 0 }
    /^```/ { fence = !fence }
    !fence && /^## / { flush(); n++; print n "\t" substr($0, 4) > (out "/index") }
    { print > (out "/" n) }
  ' "$1"
  # Trailing blank lines do not count as section content.
  local f
  for f in "$2"/[0-9]*; do
    [[ -f "$f" ]] && printf '%s\n' "$(cat "$f")" >"$f.t" && mv "$f.t" "$f"
  done
}

# Prints the drifted section headings (one per line); empty output = match.
section_drift() {   # template local
  local t="${tmp_dir}/sec.t" l="${tmp_dir}/sec.l" num head lnum
  rm -rf "$t" "$l"
  split_sections "$1" "$t"
  split_sections "$2" "$l"
  while IFS=$'\t' read -r num head; do
    lnum="$(awk -F'\t' -v h="$head" '$2 == h { print $1; exit }' "$l/index")"
    if [[ -z "$lnum" ]] || ! cmp -s "$t/$num" "$l/$lnum"; then
      printf '%s\n' "$head"
    fi
  done <"$t/index"
}

json_status_line() {   # settings file -> normalized statusLine JSON (~ expanded)
  jq -S --arg home "${HOME}" '.statusLine // empty
    | if type == "object" and (.command | type) == "string"
      then .command |= gsub("~/"; $home + "/") else . end' "$1" 2>/dev/null
}

# Sets item_status / item_note for one item.
check_item() {   # id type template local
  local id="$1" type="$2" tpl="$3" loc="$4" a b
  item_status=OK
  item_note=""
  if [[ ! -f "$tpl" ]]; then
    item_status=MISSING; item_note="repo template missing: ${tpl}"; return
  fi
  if [[ ! -f "$loc" ]]; then
    item_status=MISSING; item_note="${loc}"; return
  fi
  case "$type" in
    exact)
      cmp -s "$tpl" "$loc" || { item_status=DRIFT; item_note="${loc} differs from repo"; }
      ;;
    exact-json)
      a="$(jq -n --slurpfile v "$tpl" '{statusLine: $v[0]}' | json_status_line /dev/stdin)"
      b="$(json_status_line "$loc")"
      if [[ -z "$b" ]]; then
        item_status=MISSING; item_note="no statusLine in ${loc}"
      elif [[ "$a" != "$b" ]]; then
        item_status=DRIFT; item_note="statusLine in ${loc} differs from installer"
      fi
      ;;
    prefix)
      effective_lines "$tpl" >"${tmp_dir}/p.t"
      effective_lines "$loc" | head -n "$(wc -l <"${tmp_dir}/p.t")" >"${tmp_dir}/p.l"
      if ! cmp -s "${tmp_dir}/p.t" "${tmp_dir}/p.l"; then
        item_status=DRIFT
        item_note="$(diff "${tmp_dir}/p.t" "${tmp_dir}/p.l" | grep -c '^[<>]') effective lines differ from repo"
      fi
      ;;
    contains)
      a="$(missing_lines "$tpl" "$loc" | wc -l)"
      ((a == 0)) || { item_status=DRIFT; item_note="${a} repo line(s) not found in order"; }
      ;;
    sections)
      a="$(section_drift "$tpl" "$loc" | paste -sd ';' -)"
      [[ -z "$a" ]] || { item_status=DRIFT; item_note="sections: ${a//;/; }"; }
      ;;
  esac
}

missing_lines() {   # template local: template effective lines not matched in order
  awk 'NR == FNR { want[++n] = $0; next } i < n && $0 == want[i + 1] { i++ }
       END { for (k = i + 1; k <= n; k++) print want[k] }' \
    <(effective_lines "$1") <(effective_lines "$2")
}

find_item() {   # id -> sets it_type it_tpl it_loc
  local entry
  for entry in "${items[@]}"; do
    IFS='|' read -r it_id it_type it_tpl it_loc <<<"$entry"
    [[ "$it_id" == "$1" ]] && return 0
  done
  return 1
}

is_ignored() { [[ -f "${ignore_file}" ]] && grep -Fxq -- "$1" "${ignore_file}"; }

# ── --diff ───────────────────────────────────────────────────────────────────
show_diff() {
  local id="$1" name
  if [[ "$id" == skill:* ]]; then
    name="${id#skill:}"
    [[ -n "${repo}" && -d "${repo}/skills/${name}" ]] || { echo "Not a personal skill in the repo: ${name}" >&2; exit 2; }
    echo "Files differing between ~/.agents/skills/${name} and ${repo}/skills/${name}:"
    diff -rq "${HOME}/.agents/skills/${name}" "${repo}/skills/${name}" 2>&1 |
      sed -e "s|${HOME}/.agents/skills/|installed/|g" -e "s|${repo}/skills/|repo/|g"
    return 0
  fi
  find_item "$id" || { echo "Unknown item: ${id}" >&2; exit 2; }
  prepare_templates
  [[ -f "$it_tpl" && -f "$it_loc" ]] || { echo "Missing: ${it_tpl} or ${it_loc}"; return 0; }
  case "$it_type" in
    exact) diff -u --label "repo" --label "local" "$it_tpl" "$it_loc" ;;
    exact-json)
      diff -u --label "repo statusLine" --label "local statusLine" \
        <(jq -n --slurpfile v "$it_tpl" '{statusLine: $v[0]}' | json_status_line /dev/stdin) \
        <(json_status_line "$it_loc")
      ;;
    prefix)
      diff -u --label "repo (effective lines)" --label "local (effective lines)" \
        <(effective_lines "$it_tpl") <(effective_lines "$it_loc")
      ;;
    contains)
      echo "Repo lines missing from ${it_loc} (in order):"
      missing_lines "$it_tpl" "$it_loc" | sed 's/^/- /'
      ;;
    sections)
      local t="${tmp_dir}/sec.t" l="${tmp_dir}/sec.l" head num lnum
      section_drift "$it_tpl" "$it_loc" >"${tmp_dir}/drift"
      while IFS= read -r head; do
        num="$(awk -F'\t' -v h="$head" '$2 == h { print $1; exit }' "$t/index")"
        lnum="$(awk -F'\t' -v h="$head" '$2 == h { print $1; exit }' "$l/index")"
        printf '=== %s ===\n' "$head"
        if [[ -z "$lnum" ]]; then
          echo "(section missing locally; repo version:)"
          cat "$t/$num"
        else
          diff -u --label "repo" --label "local" "$t/$num" "$l/$lnum"
        fi
      done <"${tmp_dir}/drift"
      ;;
  esac
  return 0
}

if [[ -n "${diff_id}" ]]; then
  show_diff "${diff_id}"
  exit 0
fi

# ── --sync ───────────────────────────────────────────────────────────────────
if [[ -n "${sync_id}" ]]; then
  [[ "${sync_to}" == local || "${sync_to}" == repo ]] || { echo "--sync needs --to local|repo" >&2; exit 2; }
  find_item "${sync_id}" || { echo "Unknown item: ${sync_id}" >&2; exit 2; }
  [[ "$it_type" == exact || "$it_type" == exact-json ]] || {
    echo "${sync_id} mixes shared and personal content; merge it by hand (see --diff ${sync_id})" >&2
    exit 2
  }
  prepare_templates
  [[ -s "$it_tpl" ]] || { echo "Repo template unavailable for ${sync_id}: ${it_tpl}" >&2; exit 1; }
  if [[ "${sync_to}" == local && -L "$it_loc" ]]; then
    echo "Refusing to replace symlink ${it_loc} -> $(readlink "$it_loc"); update its target instead" >&2
    exit 1
  fi
  stamp="$(date +%Y%m%d%H%M%S)"
  if [[ "$it_type" == exact-json ]]; then
    [[ "${sync_to}" == local ]] || {
      echo "statusline-setting comes from scripts/install-claude-statusline.sh; edit that script instead" >&2
      exit 2
    }
    [[ -f "$it_loc" ]] && cp -p "$it_loc" "${it_loc}.bak.${stamp}"
    [[ -f "$it_loc" ]] || { mkdir -p "$(dirname "$it_loc")"; echo '{}' >"$it_loc"; }
    jq --slurpfile v "$it_tpl" '. + {statusLine: $v[0]}' "$it_loc" >"${tmp_dir}/settings" &&
      cat "${tmp_dir}/settings" >"$it_loc"
  elif [[ "${sync_to}" == local ]]; then
    [[ -f "$it_loc" ]] && cp -p "$it_loc" "${it_loc}.bak.${stamp}"
    mode=0644
    [[ "${sync_id}" == statusline-script ]] && mode=0755
    mkdir -p "$(dirname "$it_loc")"
    install -m "$mode" "$it_tpl" "$it_loc"
    if [[ "${sync_id}" == p10k ]]; then
      # Keep install-prompt-config.sh treating the file as unmodified.
      mkdir -p "${HOME}/.local/state/bootstrap-dev-machine"
      sha256sum "$it_tpl" | awk '{print $1}' >"${HOME}/.local/state/bootstrap-dev-machine/p10k.sha256"
    fi
  else
    [[ -n "${repo}" ]] || { echo "No repository checkout found; pass --repo" >&2; exit 2; }
    [[ -f "$it_loc" ]] || { echo "Nothing to copy: ${it_loc} is missing" >&2; exit 2; }
    cat "$it_loc" >"$it_tpl"
  fi
  check_item "${sync_id}" "$it_type" "$it_tpl" "$it_loc"
  printf '%-8s %s\n' "${item_status}" "${sync_id}"
  [[ "${item_status}" == OK ]] && [[ "${sync_to}" == repo ]] && git -C "${repo}" status --short
  [[ "${item_status}" == OK ]]
  exit
fi

# ── Report ───────────────────────────────────────────────────────────────────
problems=0
declare -A counts=()
report() {   # status section id note
  local status="$1"
  if [[ "$status" != OK && "$status" != EXTRA && "$status" != SKIP ]] && is_ignored "$3"; then
    status=IGNORED
  fi
  counts[$status]=$(( ${counts[$status]:-0} + 1 ))
  case "$status" in MISSING|DRIFT|STALE|SOURCE|WARN) problems=$((problems + 1)) ;; esac
  printf '%-8s %-9s %-30s %s\n' "$status" "$2" "$3" "$4"
}

echo "repo: ${repo:-<none: read-only checks against ${skill_dir}>}"

echo
echo "== packages =="
if [[ "${skip_packages}" == true ]]; then
  echo "skipped"
else
  pkg_out="$(bash "${skill_dir}/scripts/check-dev-machine.sh" 2>&1)"
  if [[ "${verbose}" == true ]]; then
    printf '%s\n' "${pkg_out}"
  else
    pkg_ok="$(grep -c '^OK  ' <<<"${pkg_out}")"
    while read -r _ kind what rest; do
      case "$kind" in command|path) pkg_status=MISSING ;; *) pkg_status=WARN ;; esac
      report "${pkg_status}" packages "${kind}:${what##*/}" "${what} ${rest}"
    done < <(grep '^WARN ' <<<"${pkg_out}" | grep -v 'checks completed')
    printf '%-8s %-9s %s\n' OK packages "${pkg_ok} checks passed (--verbose for all)"
  fi
fi

manifest="${repo:+${repo}/manifests/global-skills.json}"
agent_flags="-a codex -a claude-code -a pi"   # same agents as install-global-skills.sh
declare -A known=()
skill_present() {   # name -> "agents claude" presence words
  local where=""
  [[ -f "${HOME}/.agents/skills/$1/SKILL.md" ]] && where+="agents "
  [[ -e "${HOME}/.claude/skills/$1/SKILL.md" ]] && where+="claude"
  printf '%s' "$where"
}

echo
echo "== third-party skills =="
if [[ -z "${manifest}" || ! -f "${manifest}" ]] || ! command -v jq >/dev/null 2>&1; then
  echo "SKIP     no repository manifest or jq"
else
  while IFS=$'\t' read -r src name; do
    known[$name]=1
    where="$(skill_present "$name")"
    locked="$(jq -r --arg n "$name" '.skills[$n].source // empty' "${lock_file}" 2>/dev/null)"
    if [[ -z "$where" ]]; then
      report MISSING skills "skill:${name}" "npx skills add ${src} --skill ${name} -g ${agent_flags} -y"
    elif [[ "$where" != "agents claude" ]]; then
      report MISSING skills "skill:${name}" "only in ~/.${where% }/skills; reinstall: npx skills add ${src} --skill ${name} -g ${agent_flags} -y"
    elif [[ "$locked" != "$src" ]]; then
      report SOURCE skills "skill:${name}" "lock source '${locked:-none}', manifest ${src}"
    else
      report OK skills "skill:${name}" "${src}"
    fi
  done < <(jq -r '.packages[] | .repo as $r | .skills[] | [$r, .] | @tsv' "${manifest}")
fi

echo
echo "== personal skills =="
if [[ -z "${repo}" ]]; then
  echo "SKIP     no repository checkout; pass --repo"
else
  for dir in "${repo}"/skills/*/; do
    name="$(basename "$dir")"
    known[$name]=1
    where="$(skill_present "$name")"
    if [[ -z "$where" ]]; then
      report MISSING personal "skill:${name}" "npx skills add ${repo} --skill ${name} -g ${agent_flags} -y --full-depth"
    elif [[ "$where" != "agents claude" ]]; then
      report MISSING personal "skill:${name}" "only in ~/.${where% }/skills"
    elif ! diff -rq "${HOME}/.agents/skills/${name}" "${dir%/}" >/dev/null 2>&1; then
      report STALE personal "skill:${name}" "installed copy differs from repo (--diff skill:${name})"
    else
      report OK personal "skill:${name}" ""
    fi
  done
fi
extras=()
for path in "${HOME}"/.agents/skills/*/SKILL.md "${HOME}"/.claude/skills/*/SKILL.md; do
  [[ -e "$path" ]] || continue
  name="$(basename "$(dirname "$path")")"
  [[ -n "${known[$name]:-}" ]] && continue
  known[$name]=1
  extras+=("$name")
done
if ((${#extras[@]})); then
  report EXTRA skills "-" "not in manifest or repo: ${extras[*]}"
fi

echo
echo "== configs =="
prepare_templates
for entry in "${items[@]}"; do
  IFS='|' read -r it_id it_type it_tpl it_loc <<<"$entry"
  check_item "$it_id" "$it_type" "$it_tpl" "$it_loc"
  report "${item_status}" config "$it_id" "${item_note}"
done

echo
summary=""
for status in OK MISSING DRIFT STALE SOURCE WARN EXTRA IGNORED; do
  [[ -n "${counts[$status]:-}" ]] && summary+="${status}=${counts[$status]} "
done
echo "summary: ${summary% }"
((problems == 0))
