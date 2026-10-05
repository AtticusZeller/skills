#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
installer="${script_dir}/install-tmux-baseline.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
unset XDG_CONFIG_HOME

home="${tmp_dir}/home with spaces"
repo="${home}/.local/share/oh-my-tmux"
config="${home}/.config/tmux"
mkdir -p "${repo}"
printf 'set -g prefix2 C-a\n' >"${repo}/.tmux.conf"
printf '# upstream local defaults\n' >"${repo}/.tmux.conf.local"

bash "${installer}" --target-home "${home}" --dry-run
[[ ! -e "${config}" ]]
bash "${installer}" --target-home "${home}"
[[ "$(readlink "${config}/tmux.conf")" == "${repo}/.tmux.conf" ]]
cmp "${repo}/.tmux.conf.local" "${config}/tmux.conf.local"
printf '# user customization\n' >>"${config}/tmux.conf.local"
cp "${config}/tmux.conf.local" "${tmp_dir}/expected.local"
bash "${installer}" --target-home "${home}"
cmp "${tmp_dir}/expected.local" "${config}/tmux.conf.local"
echo '[PASS] upstream template fidelity, idempotency, and local customization preservation'

conflict_home="${tmp_dir}/conflict"
mkdir -p "${conflict_home}/.config/tmux"
printf '# existing config\n' >"${conflict_home}/.config/tmux/tmux.conf"
if bash "${installer}" --target-home "${conflict_home}"; then
  echo '[FAIL] replaced conflicting config' >&2
  exit 1
fi
[[ ! -e "${conflict_home}/.local" ]]
[[ "$(<"${conflict_home}/.config/tmux/tmux.conf")" == '# existing config' ]]
printf '# legacy config\n' >"${conflict_home}/.tmux.conf"
if bash "${installer}" --target-home "${conflict_home}"; then
  echo '[FAIL] ignored home-level config precedence' >&2
  exit 1
fi
echo '[PASS] conflicting configurations are preserved before any deployment'

dry_home="${tmp_dir}/dry"
mkdir -p "${dry_home}"
bash "${installer}" --target-home "${dry_home}" --dry-run
[[ ! -e "${dry_home}/.local" && ! -e "${dry_home}/.config" ]]
echo '[PASS] dry run does not clone or write files'

xdg_home="${tmp_dir}/xdg-home"
mkdir -p "${xdg_home}/.local/share"
cp -R "${repo}" "${xdg_home}/.local/share/oh-my-tmux"
XDG_CONFIG_HOME="${tmp_dir}/xdg-config" bash "${installer}" --target-home "${xdg_home}"
cmp "${repo}/.tmux.conf.local" "${tmp_dir}/xdg-config/tmux/tmux.conf.local"
[[ ! -e "${xdg_home}/.config" ]]
echo '[PASS] XDG_CONFIG_HOME is respected'
