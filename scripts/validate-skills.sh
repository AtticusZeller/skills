#!/usr/bin/env bash
set -euo pipefail

if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
  # shellcheck disable=SC1091
  . "$HOME/.nvm/nvm.sh"
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
validator="/root/.codex/skills/.system/skill-creator/scripts/quick_validate.py"

if [[ ! -f "$validator" ]]; then
  echo "Missing validator: $validator" >&2
  exit 1
fi

for skill_dir in "$repo_root"/skills/*; do
  [[ -d "$skill_dir" ]] || continue
  env -u UV_DEFAULT_INDEX -u PIP_INDEX_URL \
    uv run --with pyyaml --default-index https://pypi.org/simple \
    python "$validator" "$skill_dir"
done

npx skills add "$repo_root" --list --full-depth
bash "$repo_root/scripts/install-global-skills.sh" --dry-run
