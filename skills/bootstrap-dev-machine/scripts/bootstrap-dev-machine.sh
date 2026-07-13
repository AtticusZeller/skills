#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
asset_dir="${script_dir}/../assets"

dry_run=false
use_proxy=true
skip_packages=false
skip_conda=false
skip_skills=false
skip_context7=false
enable_dsw_persistent_prompt=false

proxy_url="${PROXY_URL:-http://127.0.0.1:7890}"
python_version="${BOOTSTRAP_PYTHON_VERSION:-3.12}"
node_version="${BOOTSTRAP_NODE_VERSION:-24}"
nvm_install_version="${BOOTSTRAP_NVM_VERSION:-v0.40.5}"
miniforge_version="${BOOTSTRAP_MINIFORGE_VERSION:-26.3.2-3}"
conda_prefix="${HOME}/miniforge3"

warnings=0
current_phase="startup"
manual_actions=()

usage() {
  cat <<'EOF'
Usage: bootstrap-dev-machine.sh [options]

Options:
  --dry-run              Print commands without changing the machine
  --no-proxy             Do not export or configure proxy settings
  --skip-packages        Skip system package installation
  --skip-conda           Skip Miniforge (conda) installation
  --skip-skills          Skip personal and external agent skill installation
  --skip-context7        Install skills without running Context7 setup
  --enable-dsw-persistent-prompt
                        Append the Alibaba Cloud DSW storage prompt to ~/.codex/AGENTS.md
  -h, --help             Show this help

Environment:
  PROXY_URL              Proxy URL (default: http://127.0.0.1:7890)
  BOOTSTRAP_PYTHON_VERSION  uv-managed Python version (default: 3.12)
  BOOTSTRAP_NODE_VERSION    nvm-managed Node major version (default: 24)
  BOOTSTRAP_NVM_VERSION     nvm installer tag (default: v0.40.5)
  BOOTSTRAP_MINIFORGE_VERSION  Miniforge release tag (default: 26.3.2-3)
  PERSONAL_SKILLS_DIR    Skills repository checkout (default: $HOME/skills)
EOF
}

while (($#)); do
  case "$1" in
    --dry-run) dry_run=true ;;
    --no-proxy) use_proxy=false ;;
    --skip-packages) skip_packages=true ;;
    --skip-conda) skip_conda=true ;;
    --skip-skills) skip_skills=true ;;
    --skip-context7) skip_context7=true ;;
    --enable-dsw-persistent-prompt) enable_dsw_persistent_prompt=true ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

[[ "${python_version}" =~ ^[0-9]+(\.[0-9]+)?$ ]] || {
  echo "Invalid BOOTSTRAP_PYTHON_VERSION: ${python_version}" >&2
  exit 2
}
[[ "${node_version}" =~ ^[0-9]+$ ]] || {
  echo "Invalid BOOTSTRAP_NODE_VERSION: ${node_version}" >&2
  exit 2
}
[[ "${nvm_install_version}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "Invalid BOOTSTRAP_NVM_VERSION: ${nvm_install_version}" >&2
  exit 2
}
[[ "${miniforge_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+$ ]] || {
  echo "Invalid BOOTSTRAP_MINIFORGE_VERSION: ${miniforge_version}" >&2
  exit 2
}

info() {
  printf '[INFO] %s\n' "$*"
}

warn() {
  warnings=$((warnings + 1))
  printf '[WARN] %s\n' "$*" >&2
}

die() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

phase() {
  current_phase="$1"
  printf '\n== %s ==\n' "${current_phase}"
}

manual() {
  manual_actions+=("$*")
}

print_command() {
  printf '[DRY-RUN]'
  printf ' %q' "$@"
  printf '\n'
}

run() {
  if [[ "${dry_run}" == true ]]; then
    print_command "$@"
    return 0
  fi
  "$@"
}

run_shell() {
  local command="$1"
  if [[ "${dry_run}" == true ]]; then
    print_command bash -o pipefail -c "${command}"
    return 0
  fi
  bash -o pipefail -c "${command}"
}

run_root() {
  if ((EUID == 0)); then
    run "$@"
  elif command -v sudo >/dev/null 2>&1; then
    run sudo "$@"
  else
    die "Root privileges or sudo are required for system packages"
  fi
}

run_node() {
  if [[ "${dry_run}" == true ]]; then
    print_command bash -c 'source "$HOME/.nvm/nvm.sh" && "$@"' bash "$@"
    return 0
  fi
  bash -c 'source "$HOME/.nvm/nvm.sh" && "$@"' bash "$@"
}

trap 'printf "[ERROR] phase failed: %s (line %s)\n" "${current_phase}" "${LINENO}" >&2' ERR

configure_proxy() {
  phase "Proxy"
  if [[ "${use_proxy}" != true ]]; then
    info "Proxy configuration skipped"
    return
  fi

  export http_proxy="${proxy_url}"
  export https_proxy="${proxy_url}"
  export HTTP_PROXY="${proxy_url}"
  export HTTPS_PROXY="${proxy_url}"
  export no_proxy="${no_proxy:-localhost,127.0.0.1}"
  export NO_PROXY="${NO_PROXY:-${no_proxy}}"

  if command -v git >/dev/null 2>&1; then
    run git config --global http.proxy "${proxy_url}"
    run git config --global https.proxy "${proxy_url}"
    info "Shell and Git proxy settings configured"
  else
    info "Shell proxy configured; Git settings will follow package installation"
  fi
}

install_system_packages() {
  phase "System packages"
  if [[ "${skip_packages}" == true ]]; then
    info "System packages skipped"
    return
  fi

  local manager
  local -a required optional
  if command -v apt-get >/dev/null 2>&1; then
    manager=apt-get
    required=(zsh git curl wget unzip ca-certificates tmux)
    optional=(bat fzf ripgrep fd-find tree htop jq ffmpeg gh fonts-powerline)
    run_root apt-get update
  elif command -v dnf >/dev/null 2>&1; then
    manager=dnf
    required=(zsh git curl wget unzip ca-certificates tmux)
    optional=(bat fzf ripgrep fd-find tree htop jq ffmpeg gh)
  elif command -v yum >/dev/null 2>&1; then
    manager=yum
    required=(zsh git curl wget unzip ca-certificates tmux)
    optional=(bat fzf ripgrep fd-find tree htop jq ffmpeg gh)
  else
    die "Unsupported package manager; use --skip-packages after installing base tools"
  fi

  run_root "${manager}" install -y "${required[@]}"
  local package
  for package in "${optional[@]}"; do
    if ! run_root "${manager}" install -y "${package}"; then
      warn "Optional package unavailable: ${package}"
    fi
  done

  if [[ "${use_proxy}" == true ]]; then
    run git config --global http.proxy "${proxy_url}"
    run git config --global https.proxy "${proxy_url}"
  fi

  run mkdir -p "${HOME}/.local/bin"
  if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
    run ln -sfn "$(command -v batcat)" "${HOME}/.local/bin/bat"
  fi
  if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
    run ln -sfn "$(command -v fdfind)" "${HOME}/.local/bin/fd"
  fi
}

install_uv_tool() {
  local command="$1"
  local package="$2"
  if command -v "${command}" >/dev/null 2>&1; then
    info "${command} already installed"
    return
  fi
  run env -u UV_DEFAULT_INDEX -u PIP_INDEX_URL \
    uv tool install --python "${python_version}" \
    --default-index https://pypi.org/simple "${package}"
}

install_conda() {
  phase "Miniforge (conda)"
  if [[ "${skip_conda}" == true ]]; then
    info "Miniforge installation skipped"
    return
  fi

  local conda_bin="${conda_prefix}/bin/conda"
  if [[ -x "${conda_bin}" ]]; then
    info "Miniforge already installed: ${conda_prefix}"
    return
  fi
  if [[ -e "${conda_prefix}" ]]; then
    die "Cannot install Miniforge over existing path: ${conda_prefix}"
  fi

  local installer_name="Miniforge3-${miniforge_version}-$(uname)-$(uname -m).sh"
  local installer_url="https://github.com/conda-forge/miniforge/releases/download/${miniforge_version}/${installer_name}"
  if [[ "${dry_run}" == true ]]; then
    print_command curl -fsSL "${installer_url}" -o "<temporary-installer>"
    print_command curl -fsSL "${installer_url}.sha256" -o "<temporary-checksum>"
    print_command sha256sum -c "<temporary-checksum>"
    print_command bash "<temporary-installer>" -b -p "${conda_prefix}"
    print_command "${conda_bin}" config --set auto_activate_base false
    return
  fi

  local tmp_dir installer checksum
  tmp_dir="$(mktemp -d)"
  installer="${tmp_dir}/${installer_name}"
  checksum="${installer}.sha256"
  if ! curl -fsSL "${installer_url}" -o "${installer}"; then
    rm -rf "${tmp_dir}"
    die "Failed to download Miniforge installer"
  fi
  if ! curl -fsSL "${installer_url}.sha256" -o "${checksum}"; then
    rm -rf "${tmp_dir}"
    die "Failed to download Miniforge checksum"
  fi
  if ! (cd "${tmp_dir}" && sha256sum -c "$(basename "${checksum}")"); then
    rm -rf "${tmp_dir}"
    die "Miniforge installer checksum verification failed"
  fi
  if ! bash "${installer}" -b -p "${conda_prefix}"; then
    rm -rf "${tmp_dir}"
    die "Miniforge installation failed"
  fi
  rm -rf "${tmp_dir}"
  "${conda_bin}" config --set auto_activate_base false
}

install_python_tools() {
  phase "uv, Python, and Python CLIs"
  run mkdir -p "${HOME}/.local/bin"
  export PATH="${HOME}/.local/bin:${PATH}"

  if ! command -v uv >/dev/null 2>&1; then
    run_shell 'curl -LsSf https://astral.sh/uv/install.sh | sh'
  fi
  if [[ "${dry_run}" != true ]] && ! command -v uv >/dev/null 2>&1; then
    die "uv installation completed but uv is not on PATH"
  fi

  run uv python install "${python_version}"
  install_uv_tool sbc sing-box-cli
  install_uv_tool nvitop nvitop
  install_uv_tool wandb wandb
}

deploy_sbc_helpers() {
  phase "sing-box helpers"
  local name
  for name in sbc-start sbc-stop sbc-status; do
    [[ -f "${asset_dir}/${name}" ]] || die "Missing asset: ${asset_dir}/${name}"
    run install -m 0755 "${asset_dir}/${name}" "${HOME}/.local/bin/${name}"
  done

  if [[ ! -f "${HOME}/.config/sing-box/config.json" ]]; then
    manual "Create ~/.config/sing-box/config.json, then run sbc-start"
  fi
}

install_node() {
  phase "nvm and Node"
  export NVM_DIR="${HOME}/.nvm"
  if [[ ! -s "${NVM_DIR}/nvm.sh" ]]; then
    run_shell "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_install_version}/install.sh | PROFILE=/dev/null bash"
  fi
  run_node nvm install "${node_version}"
  run_node nvm alias default "${node_version}"
}

install_developer_clis() {
  phase "Developer CLIs"
  if ! command -v claude >/dev/null 2>&1; then
    run_shell 'curl -fsSL https://claude.ai/install.sh | bash'
  else
    info "claude already installed"
  fi

  if ! command -v hf >/dev/null 2>&1; then
    run_shell 'curl -LsSf https://hf.co/cli/install.sh | bash'
  else
    info "hf already installed"
  fi

  if ! command -v gh >/dev/null 2>&1; then
    warn "gh was not available from the system package manager"
    manual "Install GitHub CLI (gh) from its official package or release"
  fi
  if ! command -v codex >/dev/null 2>&1; then
    warn "codex is not installed automatically"
    manual "Install Codex with the supported entry point for this host"
  fi
  if ! command -v cc-switch >/dev/null 2>&1; then
    warn "cc-switch is not installed automatically"
    manual "Install cc-switch from its official release if needed"
  fi
}

clone_if_missing() {
  local url="$1"
  local target="$2"
  if [[ -d "${target}" ]]; then
    info "Already present: ${target}"
    return
  fi
  run git clone --depth=1 "${url}" "${target}"
}

install_zsh_baseline() {
  phase "zsh baseline"
  local zsh_custom="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}"

  if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
    run_shell 'RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
  fi

  clone_if_missing https://github.com/romkatv/powerlevel10k.git \
    "${zsh_custom}/themes/powerlevel10k"
  clone_if_missing https://github.com/zsh-users/zsh-autosuggestions \
    "${zsh_custom}/plugins/zsh-autosuggestions"
  clone_if_missing https://github.com/zsh-users/zsh-syntax-highlighting \
    "${zsh_custom}/plugins/zsh-syntax-highlighting"
  clone_if_missing https://github.com/Pilaton/OhMyZsh-full-autoupdate \
    "${zsh_custom}/plugins/ohmyzsh-full-autoupdate"
  clone_if_missing https://github.com/fdellwing/zsh-bat \
    "${zsh_custom}/plugins/zsh-bat"

  local template="${asset_dir}/zshrc.server"
  local target="${HOME}/.zshrc"
  local state_dir="${HOME}/.local/state/bootstrap-dev-machine"
  local hash_file="${state_dir}/zshrc.sha256"
  local template_hash current_hash previous_hash
  local preserve_local=false
  [[ -f "${template}" ]] || die "Missing asset: ${template}"
  template_hash="$(sha256sum "${template}" | awk '{print $1}')"

  if [[ -f "${target}" && -f "${hash_file}" ]]; then
    current_hash="$(sha256sum "${target}" | awk '{print $1}')"
    previous_hash="$(<"${hash_file}")"
    if [[ "${current_hash}" != "${previous_hash}" && "${current_hash}" != "${template_hash}" ]]; then
      preserve_local=true
      warn "Preserving locally modified .zshrc"
      manual "Merge updates from ${template} into ~/.zshrc"
    fi
  fi

  if [[ "${preserve_local}" != true ]]; then
    if [[ -f "${target}" ]] && ! cmp -s "${template}" "${target}"; then
      run cp "${target}" "${target}.bak.$(date +%Y%m%d%H%M%S)"
    fi
    if [[ ! -f "${target}" ]] || ! cmp -s "${template}" "${target}"; then
      run install -m 0644 "${template}" "${target}"
    else
      info ".zshrc already matches the baseline"
    fi
    if [[ "${dry_run}" == true ]]; then
      print_command mkdir -p "${state_dir}"
      printf '[DRY-RUN] record zsh template hash in %q\n' "${hash_file}"
    else
      mkdir -p "${state_dir}"
      printf '%s\n' "${template_hash}" >"${hash_file}"
    fi
  fi

  if [[ ! -f "${HOME}/.p10k.zsh" ]]; then
    manual "Run p10k configure in an interactive zsh session"
  fi

  local zsh_path
  zsh_path="$(command -v zsh || true)"
  if [[ -n "${zsh_path}" && "${SHELL:-}" != "${zsh_path}" ]]; then
    if ((EUID != 0)); then
      manual "Run chsh -s ${zsh_path} where login-shell changes persist"
    elif ! run chsh -s "${zsh_path}"; then
      warn "Could not change the login shell to zsh"
      manual "Run chsh -s ${zsh_path} where login-shell changes persist"
    fi
  fi
}

install_agent_skills() {
  phase "Agent skills"
  if [[ "${skip_skills}" == true ]]; then
    info "Agent skill installation skipped"
    return
  fi

  local source_repo repo_dir
  source_repo="$(cd "${script_dir}/../../.." && pwd)"
  if [[ -d "${source_repo}/.git" && -x "${source_repo}/scripts/install-global-skills.sh" ]]; then
    repo_dir="${source_repo}"
  else
    repo_dir="${PERSONAL_SKILLS_DIR:-${HOME}/skills}"
    if [[ ! -d "${repo_dir}/.git" ]]; then
      if [[ -e "${repo_dir}" ]]; then
        warn "Cannot clone personal skills over existing path: ${repo_dir}"
        manual "Move or initialize ${repo_dir}, then install personal/global skills"
        return
      fi
      run git clone https://github.com/AtticusZeller/skills.git "${repo_dir}"
    fi
  fi

  run_node npx skills add "${repo_dir}" --skill '*' -g -y --full-depth
  if [[ "${dry_run}" == true || -x "${repo_dir}/scripts/install-global-skills.sh" ]]; then
    if [[ "${skip_context7}" == true ]]; then
      run bash "${repo_dir}/scripts/install-global-skills.sh" --skip-context7-setup
    else
      if ! run bash "${repo_dir}/scripts/install-global-skills.sh"; then
        warn "External skill or Context7 setup did not complete"
        manual "Authenticate Context7 if required, then rerun scripts/install-global-skills.sh"
      fi
    fi
  else
    warn "Missing global skill installer in ${repo_dir}"
  fi
}

deploy_machine_handoff() {
  phase "Machine handoff"
  local -a args=(
    --target-home "${HOME}"
    --proxy-url "${proxy_url}"
    --python-version "${python_version}"
    --node-version "${node_version}"
  )
  if [[ "${dry_run}" == true ]]; then
    args+=(--dry-run)
  fi
  bash "${script_dir}/install-machine-handoff.sh" "${args[@]}"
}

deploy_dsw_persistent_prompt() {
  phase "DSW persistent storage prompt"
  if [[ "${enable_dsw_persistent_prompt}" != true ]]; then
    info "DSW persistent storage prompt skipped"
    return
  fi

  local -a args=(--target-home "${HOME}")
  if [[ "${dry_run}" == true ]]; then
    args+=(--dry-run)
  fi
  bash "${script_dir}/install-dsw-persistent-prompt.sh" "${args[@]}"
}

validate_machine() {
  phase "Validation"
  if [[ "${dry_run}" == true ]]; then
    info "Validation skipped during dry-run"
    return
  fi
  bash "${script_dir}/check-dev-machine.sh"
}

print_summary() {
  printf '\n== Summary ==\n'
  if ((warnings == 0)); then
    echo "Bootstrap completed without script warnings."
  else
    echo "Bootstrap completed with ${warnings} warning(s)."
  fi

  manual "Authenticate gh, hf, wandb, and other account-backed CLIs as needed"

  if ((${#manual_actions[@]})); then
    echo "Manual follow-up:"
    local index=1 action
    for action in "${manual_actions[@]}"; do
      printf '  %d. %s\n' "${index}" "${action}"
      index=$((index + 1))
    done
  fi
}

configure_proxy
install_system_packages
install_conda
install_python_tools
deploy_sbc_helpers
install_node
install_developer_clis
install_zsh_baseline
install_agent_skills
deploy_machine_handoff
deploy_dsw_persistent_prompt
validate_machine
print_summary
