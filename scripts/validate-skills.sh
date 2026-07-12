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

  requires_script=false
  if compgen -G "$skill_dir/references/*.template.*" >/dev/null ||
    compgen -G "$skill_dir/assets/*" >/dev/null; then
    requires_script=true
  fi
  if [[ "$requires_script" == true ]]; then
    executable_found=false
    for helper in "$skill_dir"/scripts/*; do
      if [[ -f "$helper" && -x "$helper" ]]; then
        executable_found=true
        break
      fi
    done
    if [[ "$executable_found" != true ]]; then
      echo "Skill has fixed templates/assets but no executable helper: $skill_dir" >&2
      exit 1
    fi
  fi

  regression_found=false
  for test_script in "$skill_dir"/scripts/test-*.sh; do
    [[ -f "$test_script" ]] || continue
    regression_found=true
    bash "$test_script"
  done
  if [[ "$requires_script" == true && "$regression_found" != true ]]; then
    echo "Skill has fixed templates/assets but no regression test: $skill_dir" >&2
    exit 1
  fi
done

npx skills add "$repo_root" --list --full-depth
bash "$repo_root/scripts/install-global-skills.sh" --dry-run
