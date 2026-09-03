#!/usr/bin/env bash
set -uo pipefail

target="."
failures=0

usage() {
  cat <<'EOF'
Usage: check-repo-agents.sh [--target <dir>]

Validate repository agent scaffolding without changing files.
EOF
}

ok() {
  printf '[OK] %s\n' "$*"
}

fail() {
  printf '[ERROR] %s\n' "$*" >&2
  failures=$((failures + 1))
}

while (($#)); do
  case "$1" in
    --target)
      if (($# < 2)); then
        printf '[ERROR] --target requires a value\n' >&2
        usage >&2
        exit 2
      fi
      target="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf '[ERROR] Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[[ -d "$target" ]] || {
  printf '[ERROR] Target is not a directory: %s\n' "$target" >&2
  exit 1
}
target="$(cd "$target" && pwd)"

agents="${target}/AGENTS.md"
claude="${target}/CLAUDE.md"

if [[ ! -f "$agents" || -L "$agents" ]]; then
  fail "AGENTS.md is missing or is not a regular file"
else
  required_rules=(
    'Human sets the boundaries; agent implements and verifies within them.'
    'Human owns intent, scope, architecture, interfaces, task decomposition, and acceptance criteria.'
    'Task = Change + Observable Evidence'
    'Do not add unrequested features, abstractions, dependencies, refactors, or cleanup.'
    'Do not ask the user to run checks the agent can run.'
    '## 5. Skills'
  )
  for rule in "${required_rules[@]}"; do
    grep -Fq "$rule" "$agents" || fail "AGENTS.md is missing required rule: ${rule}"
  done
  if grep -Eq '\{\{[^}]+\}\}' "$agents"; then
    fail "AGENTS.md contains unresolved placeholders"
  fi
  if grep -Eqi 'Type A ·|Type B ·|Type C−|Type C ·|cognitive-debt|managed:begin|Embedded Grill|root `cmd\.md`'; then
    fail "AGENTS.md contains a retired workflow"
  fi <"$agents"
fi

if [[ ! -f "$claude" || -L "$claude" ]]; then
  fail "CLAUDE.md is missing or is not a regular file"
elif [[ "$(cat "$claude")" != '@AGENTS.md' ]]; then
  fail "CLAUDE.md must contain only @AGENTS.md"
else
  ok "CLAUDE.md imports the authoritative AGENTS.md"
fi

check_header() {
  local relative="$1"
  local header="$2"
  local path="${target}/${relative}"
  if [[ ! -f "$path" || -L "$path" ]]; then
    fail "${relative} is missing or is not a regular file"
  elif [[ "$(sed -n '1p' "$path")" != "$header" ]]; then
    fail "${relative} does not start with '${header}'"
  else
    ok "${relative} has the expected header"
  fi
}

check_header "docs/AGENTS.md" "# Documentation Rules"
check_header "docs/workspace/plan.md" "# Workspace Plan"
check_header "docs/workspace/log.md" "# Workspace Log"
check_header "docs/workspace/overview.md" "# Workspace 概览"

if ((failures > 0)); then
  printf '[ERROR] Repository agent scaffold validation failed with %d issue(s)\n' \
    "$failures" >&2
  exit 1
fi

ok "Repository agent scaffold validation passed"
