#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
asset="${script_dir}/../assets/p10k.zsh"
target_home="$HOME"
dry_run=false
while (($#)); do
  case "$1" in
    --target-home) (($# >= 2)) || exit 2; target_home="$2"; shift 2 ;;
    --dry-run) dry_run=true; shift ;;
    -h|--help) echo 'Usage: install-prompt-config.sh [--target-home DIR] [--dry-run]'; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
[[ -d "$target_home" && -w "$target_home" && -f "$asset" ]] || exit 1
target="$target_home/.p10k.zsh"
state="$target_home/.local/state/bootstrap-dev-machine/p10k.sha256"
[[ ! -L "$target" && ( ! -e "$target" || -f "$target" ) ]] || {
  echo "Refusing to replace a non-regular prompt config: $target" >&2; exit 1;
}
hash() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}
new_hash="$(hash "$asset")"
if [[ -f "$target" ]]; then
  current_hash="$(hash "$target")"
  previous_hash=""
  [[ ! -f "$state" ]] || previous_hash="$(cat "$state")"
  if [[ "$current_hash" != "$new_hash" && "$current_hash" != "$previous_hash" ]]; then
    echo "[MANUAL] Preserved custom prompt: $target; shared template: $asset"
    exit 0
  fi
fi
if [[ "$dry_run" == true ]]; then
  echo "[DRY-RUN] Deploy shared prompt to $target"
  exit 0
fi
if [[ -f "$target" ]] && ! cmp -s "$asset" "$target"; then
  cp -p "$target" "$target.bak.$(date +%Y%m%d%H%M%S).$$"
fi
if [[ ! -f "$target" ]] || ! cmp -s "$asset" "$target"; then
  install -m 0644 "$asset" "$target"
fi
mkdir -p "$(dirname "$state")"
printf '%s\n' "$new_hash" > "$state"
echo "[OK] Shared Powerlevel10k prompt: $target"
