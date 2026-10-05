#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
defaults_file="${script_dir}/../assets/tmux-defaults.conf"
target_home="${HOME}"
dry_run=false
while (($#)); do
  case "$1" in
    --target-home)
      (($# >= 2)) || { echo '--target-home requires a value' >&2; exit 2; }
      target_home="$2"
      shift 2
      ;;
    --dry-run) dry_run=true; shift ;;
    -h|--help)
      echo 'Usage: install-tmux-baseline.sh [--target-home <dir>] [--dry-run]'
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

[[ -d "${target_home}" && -w "${target_home}" ]] || {
  echo "Target home must be a writable directory: ${target_home}" >&2
  exit 1
}
target_home="$(cd "${target_home}" && pwd)"
repo_dir="${target_home}/.local/share/oh-my-tmux"
config_dir="${XDG_CONFIG_HOME:-${target_home}/.config}/tmux"
config_file="${config_dir}/tmux.conf"
local_file="${config_dir}/tmux.conf.local"

# A home-level config takes precedence over the XDG configuration.
if [[ -e "${target_home}/.tmux.conf" || -L "${target_home}/.tmux.conf" ]]; then
  echo "Preserving ~/.tmux.conf; move it aside before installing the XDG tmux baseline" >&2
  exit 1
fi
if [[ -e "${config_file}" || -L "${config_file}" ]]; then
  if [[ ! -L "${config_file}" || "$(readlink "${config_file}")" != "${repo_dir}/.tmux.conf" ]]; then
    echo "Preserving existing tmux config: ${config_file}" >&2
    exit 1
  fi
fi
if [[ -e "${local_file}" || -L "${local_file}" ]]; then
  [[ -f "${local_file}" ]] || {
    echo "Local tmux config is not a regular file: ${local_file}" >&2
    exit 1
  }
fi

if [[ "${dry_run}" == true ]]; then
  echo "[DRY-RUN] reuse or clone gpakosz/.tmux into ${repo_dir}"
  echo "[DRY-RUN] link ${config_file} and create ${local_file} if absent"
  exit 0
fi

if [[ ! -e "${repo_dir}" ]]; then
  mkdir -p "$(dirname "${repo_dir}")"
  git clone --depth=1 --single-branch https://github.com/gpakosz/.tmux.git "${repo_dir}"
fi
[[ -f "${repo_dir}/.tmux.conf" && -f "${repo_dir}/.tmux.conf.local" ]] || {
  echo "Incomplete Oh my tmux checkout: ${repo_dir}" >&2
  exit 1
}
mkdir -p "${config_dir}"
if [[ ! -L "${config_file}" ]]; then
  ln -s "${repo_dir}/.tmux.conf" "${config_file}"
fi
if [[ ! -e "${local_file}" ]]; then
  [[ -f "${defaults_file}" ]] || {
    echo "Missing tmux defaults asset: ${defaults_file}" >&2
    exit 1
  }
  cp "${repo_dir}/.tmux.conf.local" "${local_file}"
  printf '\n' >>"${local_file}"
  cat "${defaults_file}" >>"${local_file}"
fi
echo "[INFO] Oh my tmux installed; local customizations preserved: ${local_file}"
echo "[INFO] New tmux servers load it automatically; reload running servers with:"
printf '  tmux source-file %q\n' "${config_file}"
