#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
asset_file="${script_dir}/../assets/ghostty-config.ghostty"
installer_url="https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh"

target_home="${HOME}"
dry_run=false
skip_install=false

usage() {
  cat <<'EOF'
Usage: install-ghostty-terminal.sh [options]

Install Ghostty on apt/dpkg hosts with the ghostty-ubuntu installer and deploy
the bundled Ghostty configuration to $XDG_CONFIG_HOME/ghostty/config.ghostty.

Options:
  --target-home <dir>  Home directory to configure (default: $HOME)
  --skip-install       Deploy the configuration without installing Ghostty
  --dry-run            Print actions without changing the machine
  -h, --help           Show this help
EOF
}

while (($#)); do
  case "$1" in
    --target-home)
      (($# >= 2)) || { echo '--target-home requires a value' >&2; exit 2; }
      target_home="$2"
      shift 2
      ;;
    --skip-install) skip_install=true; shift ;;
    --dry-run) dry_run=true; shift ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
  esac
done

[[ -d "${target_home}" && -w "${target_home}" ]] || {
  echo "Target home must be a writable directory: ${target_home}" >&2
  exit 1
}
target_home="$(cd "${target_home}" && pwd)"

config_dir="${XDG_CONFIG_HOME:-${target_home}/.config}/ghostty"
config_file="${config_dir}/config.ghostty"
state_dir="${target_home}/.local/state/bootstrap-dev-machine"
state_file="${state_dir}/ghostty-config.sha256"

info() {
  printf '[INFO] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*" >&2
}

die() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

install_ghostty() {
  if [[ "${skip_install}" == true ]]; then
    info "Ghostty installation skipped"
    return 0
  fi
  if command -v ghostty >/dev/null 2>&1; then
    info "Ghostty already installed: $(command -v ghostty)"
    return 0
  fi
  if ! command -v apt-get >/dev/null 2>&1 || ! command -v dpkg >/dev/null 2>&1; then
    warn "The ghostty-ubuntu installer supports apt/dpkg hosts only; install Ghostty from https://ghostty.org/docs/install"
    return 0
  fi
  if ! command -v curl >/dev/null 2>&1; then
    warn "curl is required to download the ghostty-ubuntu installer; install curl and rerun"
    return 1
  fi
  if [[ "${dry_run}" == true ]]; then
    printf '[DRY-RUN] (cd <temporary-directory> && /bin/bash -c "$(curl -fsSL %s)")\n' "${installer_url}"
    return 0
  fi

  local tmp_dir status=0
  tmp_dir="$(mktemp -d)"
  info "Installing Ghostty with the ghostty-ubuntu installer"
  # Run in a scratch directory: the installer downloads a .deb into the CWD.
  (cd "${tmp_dir}" && /bin/bash -c "$(curl -fsSL "${installer_url}")") || status=$?
  rm -rf "${tmp_dir}"
  if ((status != 0)); then
    warn "ghostty-ubuntu installer failed with exit ${status}; resolve the error and rerun install-ghostty-terminal.sh"
    return 1
  fi
  if ! command -v ghostty >/dev/null 2>&1; then
    warn "ghostty-ubuntu installer finished but ghostty is not on PATH; verify the package installation"
    return 1
  fi
  info "Ghostty installed: $(command -v ghostty)"
}

deploy_config() {
  local template_hash current_hash previous_hash preserve_local=false backup

  [[ -f "${asset_file}" ]] || die "Missing Ghostty config asset: ${asset_file}"
  [[ ! -e "${config_file}" || -f "${config_file}" ]] ||
    die "Existing Ghostty config is not a regular file: ${config_file}"

  template_hash="$(sha256sum "${asset_file}" | awk '{print $1}')"

  if [[ -f "${config_file}" && -f "${state_file}" ]]; then
    current_hash="$(sha256sum "${config_file}" | awk '{print $1}')"
    previous_hash="$(<"${state_file}")"
    if [[ "${current_hash}" != "${previous_hash}" && "${current_hash}" != "${template_hash}" ]]; then
      preserve_local=true
      warn "Preserving locally modified Ghostty config: ${config_file}; merge updates from ${asset_file}"
    fi
  fi

  if [[ "${preserve_local}" == true ]]; then
    return 0
  fi

  if [[ "${dry_run}" == true ]]; then
    if [[ -f "${config_file}" ]] && cmp -s "${asset_file}" "${config_file}"; then
      printf '[DRY-RUN] Ghostty config already matches %q\n' "${asset_file}"
    else
      printf '[DRY-RUN] install %q to %q\n' "${asset_file}" "${config_file}"
    fi
    printf '[DRY-RUN] record the Ghostty template hash in %q\n' "${state_file}"
    return 0
  fi

  mkdir -p "${config_dir}"
  if [[ -f "${config_file}" ]] && ! cmp -s "${asset_file}" "${config_file}"; then
    backup="${config_file}.bak.$(date +%Y%m%d%H%M%S)"
    cp -p "${config_file}" "${backup}"
    info "Backed up previous Ghostty config: ${backup}"
  fi
  if [[ -f "${config_file}" ]] && cmp -s "${asset_file}" "${config_file}"; then
    info "Ghostty config already matches the template"
  else
    install -m 0644 "${asset_file}" "${config_file}"
    info "Deployed Ghostty config: ${config_file}"
  fi
  mkdir -p "${state_dir}"
  printf '%s\n' "${template_hash}" >"${state_file}"
}

install_status=0
install_ghostty || install_status=$?
deploy_config
exit "${install_status}"
