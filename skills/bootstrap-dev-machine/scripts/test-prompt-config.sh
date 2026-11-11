#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
installer="$script_dir/install-prompt-config.sh"
asset="$script_dir/../assets/p10k.zsh"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
target_dir="$scratch/home with spaces"
mkdir -p "$target_dir"
bash "$installer" --target-home "$target_dir" --dry-run
[[ ! -e "$target_dir/.p10k.zsh" && ! -e "$target_dir/.local" ]]
bash "$installer" --target-home "$target_dir"
cmp "$asset" "$target_dir/.p10k.zsh"
before="$(find "$target_dir" -type f | wc -l)"
bash "$installer" --target-home "$target_dir"
[[ "$(find "$target_dir" -type f | wc -l)" == "$before" ]]
printf '\n# custom prompt\n' >> "$target_dir/.p10k.zsh"
cp "$target_dir/.p10k.zsh" "$scratch/expected"
bash "$installer" --target-home "$target_dir"
cmp "$scratch/expected" "$target_dir/.p10k.zsh"
rm "$target_dir/.local/state/bootstrap-dev-machine/p10k.sha256"
bash "$installer" --target-home "$target_dir"
cmp "$scratch/expected" "$target_dir/.p10k.zsh"
rm "$target_dir/.p10k.zsh"
ln -s "$scratch/expected" "$target_dir/.p10k.zsh"
if bash "$installer" --target-home "$target_dir"; then
  echo '[FAIL] replaced a symlink prompt' >&2; exit 1
fi
cmp "$scratch/expected" "$target_dir/.p10k.zsh"
printf '[PASS] shared prompt fidelity, idempotency, custom config preservation, and symlink refusal\n'
if command -v zsh >/dev/null 2>&1; then zsh -n "$asset"; fi
