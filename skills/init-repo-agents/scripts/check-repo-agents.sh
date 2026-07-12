#!/usr/bin/env bash
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_dir="$(cd "${script_dir}/.." && pwd)"
template="${skill_dir}/references/AGENTS.template.md"
target="."

managed_begin="<!-- init-repo-agents:managed:begin -->"
managed_end="<!-- init-repo-agents:managed:end -->"
module_begin="<!-- init-repo-agents:module-index:begin -->"
module_end="<!-- init-repo-agents:module-index:end -->"
failures=0

usage() {
  cat <<'EOF'
Usage: check-repo-agents.sh [--target <dir>]

Validate deterministic repository agent scaffolding without changing files.
EOF
}

info() {
  printf '[INFO] %s\n' "$*"
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
[[ -f "$template" ]] || {
  printf '[ERROR] Missing template: %s\n' "$template" >&2
  exit 1
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

extract_managed_block() {
  local source="$1"
  local output="$2"
  awk -v begin="$managed_begin" -v end="$managed_end" '
    $0 == begin {
      begin_count++
      if (begin_count == 1) {
        inside = 1
      }
    }
    inside {
      print
    }
    $0 == end {
      end_count++
      if (inside) {
        inside = 0
      }
    }
    END {
      if (begin_count != 1 || end_count != 1 || inside) {
        exit 1
      }
    }
  ' "$source" >"$output"
}

check_managed_file() {
  local name="$1"
  local path="${target}/${name}"
  local block="${tmp_dir}/${name}.managed"

  if [[ ! -f "$path" || -L "$path" ]]; then
    fail "${name} is missing or is not a regular file"
    return
  fi
  if [[ "$(sed -n '1p' "$path")" != "$managed_begin" ]]; then
    fail "${name} does not start with the managed block"
    return
  fi
  if ! extract_managed_block "$path" "$block"; then
    fail "${name} has a malformed or duplicated managed block"
    return
  fi
  if grep -Eq '\{\{[^}]+\}\}' "$block"; then
    fail "${name} contains unresolved placeholders"
  fi
  if [[ "$(grep -Fxc "$module_begin" "$block")" -ne 1 ||
        "$(grep -Fxc "$module_end" "$block")" -ne 1 ]]; then
    fail "${name} has malformed module-index boundaries"
  fi
}

check_managed_file "AGENTS.md"
check_managed_file "CLAUDE.md"

agents_block="${tmp_dir}/AGENTS.md.managed"
claude_block="${tmp_dir}/CLAUDE.md.managed"
if [[ -f "$agents_block" && -f "$claude_block" ]]; then
  if cmp -s "$agents_block" "$claude_block"; then
    ok "AGENTS.md and CLAUDE.md managed blocks are byte-identical"
  else
    fail "AGENTS.md and CLAUDE.md managed blocks differ"
  fi

  template_static="${tmp_dir}/template-static.md"
  awk -v begin="$managed_begin" -v end="$managed_end" '
    $0 == begin { inside = 1 }
    inside && $0 !~ /\{\{[^}]+\}\}/ { print }
    $0 == end { exit }
  ' "$template" >"$template_static"

  if awk '
    NR == FNR {
      expected[++count] = $0
      next
    }
    matched < count && $0 == expected[matched + 1] {
      matched++
    }
    END {
      if (matched != count) {
        exit 1
      }
    }
  ' "$template_static" "$agents_block"; then
    ok "managed block preserves every static template line in order"
  else
    fail "managed block is missing or rewrites static template content"
  fi

  grep -Eq '^# .+ · Agent Collaboration Guide$' "$agents_block" ||
    fail "project name was not rendered"
  grep -Eq '^\*\*Primary toolchain:\*\* .+' "$agents_block" ||
    fail "primary toolchain was not rendered"
  grep -Eq '^- \*\*`.+` \(conventionally `dev\.sh`\)\*\* wraps' "$agents_block" ||
    fail "entry point was not rendered"

  if cmp -s "${target}/AGENTS.md" "${target}/CLAUDE.md"; then
    info "fresh-file mirror is byte-identical"
  else
    info "full files differ only by independently preserved repository content"
  fi
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

check_header "docs/plan.md" "# Development Plan"
check_header "docs/log.md" "# Development Log"
check_header "docs/bug.md" "# Bug Journal"
check_header "cmd.md" "# Command Reference"

if [[ -f "${target}/cmd.md" ]]; then
  grep -Fq '## 常用命令' "${target}/cmd.md" ||
    fail "cmd.md is missing the common-command section"
  grep -Fq '## 待用户验证' "${target}/cmd.md" ||
    fail "cmd.md is missing the user-verification section"
fi

if ((failures > 0)); then
  printf '[ERROR] Repository agent scaffold validation failed with %d issue(s)\n' \
    "$failures" >&2
  exit 1
fi

ok "Repository agent scaffold validation passed"
