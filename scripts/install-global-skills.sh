#!/usr/bin/env bash
set -euo pipefail

if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
  # shellcheck disable=SC1091
  . "$HOME/.nvm/nvm.sh"
fi

dry_run=false
run_context7=true

for arg in "$@"; do
  case "$arg" in
    --dry-run)
      dry_run=true
      ;;
    --skip-context7-setup)
      run_context7=false
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

run_cmd() {
  if [[ "$dry_run" == true ]]; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

agent_args=(-a codex -a claude-code -a cursor)

install_skill() {
  local repo="$1"
  local skill="$2"
  run_cmd npx skills add "$repo" --skill "$skill" -g "${agent_args[@]}" -y
}

install_skill trailofbits/skills modern-python
install_skill trailofbits/skills gh-cli
install_skill huggingface/skills hf-cli
install_skill fvadicamo/dev-agent-skills git-commit
install_skill upstash/context7 context7-cli
install_skill upstash/context7 find-docs
install_skill forrestchang/andrej-karpathy-skills karpathy-guidelines
install_skill KKKKhazix/khazix-skills neat-freak
install_skill wandb/skills wandb-primary

if [[ "$run_context7" == true ]]; then
  run_cmd npx ctx7 setup --cli --claude --codex -y
fi
