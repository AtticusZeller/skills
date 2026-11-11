#!/usr/bin/env bash
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo 'Requires macOS' >&2; exit 1; }
for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  if [[ -x "$brew_bin" ]]; then eval "$("$brew_bin" shellenv)"; break; fi
done
export PATH="$HOME/.local/bin:$PATH"
missing=0
for tool in brew git rg uv jq bat fd fzf tmux gh codex claude hf wandb sbc sing-box; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '[OK] %s: %s\n' "$tool" "$(command -v "$tool")"
  else
    printf '[MISSING] %s\n' "$tool"; missing=1
  fi
done
uv python find "${BOOTSTRAP_PYTHON_VERSION:-3.12}"
if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
  set +u
  # shellcheck disable=SC1091
  source "$HOME/.nvm/nvm.sh"
  node --version
  npm --version
  set -u
else
  echo '[MISSING] nvm'; missing=1
fi
if [[ -x "$HOME/miniforge3/bin/conda" ]]; then
  "$HOME/miniforge3/bin/conda" --version
  "$HOME/miniforge3/bin/mamba" --version
else
  echo '[MANUAL] Miniforge absent (permitted with --skip-conda)'
fi
/bin/zsh -n "$HOME/.zshrc"
for resource in .oh-my-zsh/oh-my-zsh.sh .config/tmux/tmux.conf .codex/AGENTS.md .claude/CLAUDE.md; do
  if [[ -f "$HOME/$resource" ]]; then echo "[OK] $resource"; else echo "[MISSING] $resource"; missing=1; fi
done
/Applications/Ghostty.app/Contents/MacOS/ghostty +validate-config
sbc version
if ! gh auth status >/dev/null 2>&1; then echo '[MANUAL] GitHub CLI login: gh auth login'; fi
exit "$missing"
