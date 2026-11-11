#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../../.." && pwd)"
asset_dir="${script_dir}/../assets"
dry_run=false
skip_packages=false
skip_conda=false
skip_skills=false
configure_only=false
set_default=false
python_version="${BOOTSTRAP_PYTHON_VERSION:-3.12}"
node_version="${BOOTSTRAP_NODE_VERSION:-24}"
nvm_version="${BOOTSTRAP_NVM_VERSION:-v0.40.5}"
miniforge_version="${BOOTSTRAP_MINIFORGE_VERSION:-26.3.2-3}"
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=true ;;
    --skip-packages) skip_packages=true ;;
    --skip-conda) skip_conda=true ;;
    --skip-skills) skip_skills=true ;;
    --configure-only) configure_only=true ;;
    --set-default-terminal) set_default=true ;;
    -h|--help)
      echo 'Usage: bootstrap-dev-machine-macos.sh [--dry-run] [--skip-packages] [--skip-conda] [--skip-skills] [--configure-only] [--set-default-terminal]'
      exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done
[[ "$(uname -s)" == Darwin ]] || { echo 'This entry point requires macOS.' >&2; exit 1; }
((EUID != 0)) || { echo 'Run as the normal user, without sudo.' >&2; exit 1; }
[[ "$python_version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ && "$node_version" =~ ^[0-9]+$ ]] || exit 2
[[ "$nvm_version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ && "$miniforge_version" =~ ^[0-9][0-9.-]+$ ]] || exit 2
trap 'printf "[ERROR] macOS bootstrap failed at line %s; rerun after resolving the error.\n" "$LINENO" >&2' ERR

run() {
  if [[ "$dry_run" == true ]]; then
    printf '[DRY-RUN]'; printf ' %q' "$@"; printf '\n'
  else
    "$@"
  fi
}
clone() {
  [[ -e "$2" ]] || run git clone --depth=1 "$1" "$2"
}
brew_bin="$(command -v brew || true)"
[[ -n "$brew_bin" ]] || brew_bin=/opt/homebrew/bin/brew
[[ -x "$brew_bin" ]] || brew_bin=/usr/local/bin/brew
[[ -x "$brew_bin" ]] || { echo 'Install Homebrew from https://brew.sh first.' >&2; exit 1; }
eval "$("$brew_bin" shellenv)"
export PATH="$HOME/.local/bin:$PATH"

# Explicitly requested default-terminal changes happen before tool installation.
if [[ "$set_default" == true ]]; then
  run /usr/bin/swift "${script_dir}/set-default-terminal-macos.swift"
fi

if [[ "$configure_only" != true ]]; then
  if [[ "$skip_packages" != true ]]; then
    formulas=(git bash coreutils findutils gnu-sed uv ripgrep jq bat fd fzf tmux gh shellcheck sing-box)
    for formula in "${formulas[@]}"; do
      "$brew_bin" list --versions "$formula" >/dev/null 2>&1 || run "$brew_bin" install "$formula"
    done
    for cask in ghostty font-jetbrains-mono-nerd-font codex claude-code; do
      "$brew_bin" list --cask "$cask" >/dev/null 2>&1 || run "$brew_bin" install --cask "$cask"
    done
  fi
  run uv python install "$python_version"
  for spec in 'hf:huggingface_hub' 'wandb:wandb' 'sbc:sing-box-cli'; do
    tool="${spec%%:*}"; package="${spec#*:}"
    command -v "$tool" >/dev/null 2>&1 || run env -u UV_DEFAULT_INDEX -u PIP_INDEX_URL uv tool install --python "$python_version" --default-index https://pypi.org/simple "$package"
  done

  export NVM_DIR="$HOME/.nvm"
  if [[ ! -e "$NVM_DIR" ]]; then
    run git clone --depth=1 --branch "$nvm_version" https://github.com/nvm-sh/nvm.git "$NVM_DIR"
  fi
  if [[ "$dry_run" != true ]]; then
    [[ -f "$NVM_DIR/nvm.sh" ]] || { echo 'Existing nvm directory is incomplete.' >&2; exit 1; }
    # nvm is not compatible with nounset in every supported version.
    set +u
    # shellcheck disable=SC1091
    source "$NVM_DIR/nvm.sh"
    nvm install "$node_version"
    nvm alias default "$node_version"
    set -u
  else
    echo "[DRY-RUN] nvm install ${node_version}; nvm alias default ${node_version}"
  fi

  if [[ "$skip_conda" != true ]]; then
    prefix="$HOME/miniforge3"
    if [[ ! -x "$prefix/bin/conda" ]]; then
      [[ ! -e "$prefix" ]] || { echo 'Refusing to overwrite an incomplete Miniforge directory.' >&2; exit 1; }
      filename="Miniforge3-${miniforge_version}-MacOSX-$(uname -m).sh"
      url="https://github.com/conda-forge/miniforge/releases/download/${miniforge_version}/${filename}"
      if [[ "$dry_run" == true ]]; then
        echo "[DRY-RUN] Download and SHA256-verify $url; install into $prefix"
      else
        scratch="$(mktemp -d)"
        curl -fLsS --retry 3 "$url" -o "$scratch/$filename"
        curl -fLsS --retry 3 "$url.sha256" -o "$scratch/$filename.sha256"
        (cd "$scratch" && shasum -a 256 -c "$filename.sha256")
        bash "$scratch/$filename" -b -p "$prefix"
        rm -rf "$scratch"
      fi
    fi
    run "$prefix/bin/conda" config --set auto_activate_base false
    if [[ "$dry_run" != true ]]; then [[ -x "$prefix/bin/mamba" ]]; fi
  fi

  clone https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
  custom="$HOME/.oh-my-zsh/custom"
  clone https://github.com/romkatv/powerlevel10k.git "$custom/themes/powerlevel10k"
  clone https://github.com/zsh-users/zsh-autosuggestions.git "$custom/plugins/zsh-autosuggestions"
  clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$custom/plugins/zsh-syntax-highlighting"
  clone https://github.com/Pilaton/OhMyZsh-full-autoupdate.git "$custom/plugins/ohmyzsh-full-autoupdate"
  clone https://github.com/fdellwing/zsh-bat.git "$custom/plugins/zsh-bat"
  tmux_args=(bash "${script_dir}/install-tmux-baseline.sh")
  [[ "$dry_run" != true ]] || tmux_args+=(--dry-run)
  run "${tmux_args[@]}"
  run mkdir -p "$HOME/.local/bin"
  for helper in sbc-start sbc-stop sbc-status; do
    run install -m 0755 "$asset_dir/$helper" "$HOME/.local/bin/$helper"
  done
fi

prompt_args=(--target-home "$HOME")
[[ "$dry_run" != true ]] || prompt_args+=(--dry-run)
run bash "${script_dir}/install-prompt-config.sh" "${prompt_args[@]}"

if [[ "$dry_run" == true ]]; then
  run uv run --python "$python_version" python "${script_dir}/install-macos-config.py" --dry-run
else
  uv run --python "$python_version" python "${script_dir}/install-macos-config.py"
fi
handoff_args=(--platform macos --proxy-url "${PROXY_URL:-disabled}" --python-version "$python_version" --node-version "$node_version")
[[ "$dry_run" != true ]] || handoff_args+=(--dry-run)
bash "${script_dir}/install-machine-handoff.sh" "${handoff_args[@]}"

if [[ "$configure_only" != true && "$skip_skills" != true ]]; then
  run npx --yes skills add "$repo_root" --skill '*' -g -a codex -a claude-code -a cursor -y --full-depth
  # Account-backed Context7 setup is a final manual step; install its CLI first.
  command -v ctx7 >/dev/null 2>&1 || run npm install -g ctx7
  skills_args=(--skip-context7-setup)
  [[ "$dry_run" != true ]] || skills_args+=(--dry-run)
  run bash "$repo_root/scripts/install-global-skills.sh" "${skills_args[@]}"
fi
if [[ "$dry_run" != true && "$configure_only" != true ]]; then
  bash "${script_dir}/check-dev-machine-macos.sh"
fi
printf '\n[MANUAL] Account logins: gh auth login; hf auth login; wandb login; codex; claude.\n'
printf '[MANUAL] Context7 account setup: ctx7 setup --cli --claude --codex\n'
printf '[INFO] Shared Powerlevel10k prompt deployed; p10k configure is optional customization.\n'
printf '[MANUAL] Provide a private sing-box config before starting sbc-start.\n'
printf '[INFO] Open a new Ghostty window to load the MacBook shell configuration.\n'
