#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target="."
dry_run=false
refresh_skill=false

usage() {
  cat <<'EOF'
Usage: update-repo-agents.sh [options]

Refresh an initialized repository from the currently installed baseline.

Options:
  --target <dir>    Target repository root (default: current directory)
  --refresh-skill   First install/update init-repo-agents and Explain Diff globally
  --dry-run         Preview repository changes without writing them
  -h, --help        Show this help
EOF
}

while (($#)); do
  case "$1" in
    --target)
      (($# >= 2)) || {
        printf '[ERROR] --target requires a value\n' >&2
        exit 2
      }
      target="$2"
      shift 2
      ;;
    --refresh-skill)
      refresh_skill=true
      shift
      ;;
    --dry-run)
      dry_run=true
      shift
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

if [[ "$refresh_skill" == true ]]; then
  npx skills add AtticusZeller/skills \
    --skill init-repo-agents explain-diff-html explain-diff-notion \
    -g -a codex claude-code cursor -y --full-depth
fi

args=(--target "$target" --update)
if [[ "$dry_run" == true ]]; then
  args+=(--dry-run)
fi
bash "${script_dir}/init-repo-agents.sh" "${args[@]}"

if [[ "$dry_run" != true ]]; then
  bash "${script_dir}/check-repo-agents.sh" --target "$target"
fi
