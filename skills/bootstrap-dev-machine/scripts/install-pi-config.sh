#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
assets="$script_dir/../assets/pi"
agent_dir="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
settings="$agent_dir/settings.json"
shared_agents="$HOME/.codex/AGENTS.md"
dry_run=false

case "${1:-}" in
  '') ;;
  --dry-run) dry_run=true ;;
  -h|--help)
    echo 'Usage: install-pi-config.sh [--dry-run] (honours PI_CODING_AGENT_DIR; requires jq)'
    exit 0 ;;
  *) echo "Unknown option: $1" >&2; exit 2 ;;
esac
(($# <= 1)) || { echo 'Expected at most one option' >&2; exit 2; }

run() {
  if "$dry_run"; then
    printf '[DRY-RUN]'; printf ' %q' "$@"; printf '\n'
  else
    "$@"
  fi
}

command -v jq >/dev/null || { echo 'jq is required' >&2; exit 1; }
merged=''
if [[ -L "$settings" ]]; then
  echo "[INFO] Preserved symlink $settings"
elif [[ -e "$settings" ]]; then
  if ! jq -es 'length == 1 and (.[0] | type == "object")' "$settings" >/dev/null; then
    echo "[ERROR] $settings is not a JSON object; nothing installed" >&2
    exit 1
  fi
  merged="$(jq --slurpfile defaults "$assets/settings.json" '($defaults[0] * .) as $merged | select(. != $merged) | $merged' "$settings")"
fi

for file in APPEND_SYSTEM.md extensions/compact-bash.ts extensions/pi-tool-display/config.json extensions/tokyo-footer/index.ts; do
  target="$agent_dir/$file"
  if [[ -e "$target" || -L "$target" ]]; then
    echo "[INFO] Preserved existing $target"
  else
    run mkdir -p "$(dirname "$target")"
    run install -m 0644 "$assets/$file" "$target"
  fi
done

if [[ -f "$shared_agents" && ! -e "$agent_dir/AGENTS.md" && ! -L "$agent_dir/AGENTS.md" ]]; then
  run ln -s "$shared_agents" "$agent_dir/AGENTS.md"
fi

if [[ ! -e "$settings" && ! -L "$settings" ]]; then
  run install -m 0600 "$assets/settings.json" "$settings"
elif [[ -n "$merged" ]]; then
  if "$dry_run"; then
    echo "[DRY-RUN] Back up $settings and fill missing defaults"
  else
    backup="$(mktemp "${settings}.bak.XXXXXX")"
    cat "$settings" > "$backup"
    tmp="$(mktemp "${settings}.tmp.XXXXXX")"
    trap 'rm -f -- "$tmp"' EXIT
    printf '%s\n' "$merged" > "$tmp"
    mv "$tmp" "$settings"
    echo "[INFO] Filled missing defaults; backup: $backup"
  fi
fi
