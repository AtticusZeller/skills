#!/usr/bin/env bash
set -euo pipefail

case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*)
    printf '[SKIP] Ghostty baseline regression suite requires a Linux host\n'
    exit 0
    ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
installer="${script_dir}/install-ghostty-terminal.sh"
asset="${script_dir}/../assets/ghostty-config.ghostty"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
unset XDG_CONFIG_HOME

[[ -f "${asset}" ]]
bash -n "${installer}"

# The installer command itself is part of the baseline contract.
grep -Fq 'https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh' "${installer}"
grep -Fq '/bin/bash -c "$(curl -fsSL' "${installer}"

home="${tmp_dir}/home with spaces"
mkdir -p "${home}"
bash "${installer}" --target-home "${home}" --skip-install --dry-run
[[ ! -e "${home}/.config" && ! -e "${home}/.local" ]]
echo '[PASS] dry run does not deploy the config'

bash "${installer}" --target-home "${home}" --skip-install
config="${home}/.config/ghostty/config.ghostty"
cmp "${asset}" "${config}"
[[ "$(stat -c '%a' "${config}")" == 644 ]]
[[ -s "${home}/.local/state/bootstrap-dev-machine/ghostty-config.sha256" ]]
echo '[PASS] fresh deployment matches the bundled template'

bash "${installer}" --target-home "${home}" --skip-install
backups="$(find "${home}/.config/ghostty" -maxdepth 1 -name 'config.ghostty.bak.*' -print)"
[[ -z "${backups}" ]]
cmp "${asset}" "${config}"
echo '[PASS] rerun is idempotent and creates no backup'

printf '\n# local tweak\n' >>"${config}"
cp "${config}" "${tmp_dir}/local.expected"
output="$(bash "${installer}" --target-home "${home}" --skip-install 2>&1)"
cmp "${tmp_dir}/local.expected" "${config}"
[[ "${output}" == *'Preserving locally modified Ghostty config'* ]]
echo '[PASS] locally modified config is preserved for manual merge'

old_home="${tmp_dir}/old-home"
mkdir -p "${old_home}/.config/ghostty" "${old_home}/.local/state/bootstrap-dev-machine"
printf '# previous template\n' >"${old_home}/.config/ghostty/config.ghostty"
sha256sum "${old_home}/.config/ghostty/config.ghostty" |
  awk '{print $1}' >"${old_home}/.local/state/bootstrap-dev-machine/ghostty-config.sha256"
bash "${installer}" --target-home "${old_home}" --skip-install
cmp "${asset}" "${old_home}/.config/ghostty/config.ghostty"
old_backup="$(find "${old_home}/.config/ghostty" -maxdepth 1 -name 'config.ghostty.bak.*' -print -quit)"
[[ -n "${old_backup}" ]]
[[ "$(<"${old_backup}")" == '# previous template' ]]
echo '[PASS] unchanged previous deployment is updated with a backup'

xdg_home="${tmp_dir}/xdg-home"
mkdir -p "${xdg_home}"
XDG_CONFIG_HOME="${tmp_dir}/xdg-config" bash "${installer}" --target-home "${xdg_home}" --skip-install
cmp "${asset}" "${tmp_dir}/xdg-config/ghostty/config.ghostty"
[[ ! -e "${xdg_home}/.config" ]]
echo '[PASS] XDG_CONFIG_HOME is respected'

conflict_home="${tmp_dir}/conflict-home"
mkdir -p "${conflict_home}/.config/ghostty/config.ghostty"
if bash "${installer}" --target-home "${conflict_home}" --skip-install; then
  echo '[FAIL] replaced a non-regular Ghostty config' >&2
  exit 1
fi
[[ -d "${conflict_home}/.config/ghostty/config.ghostty" ]]
echo '[PASS] conflicting non-regular configs are preserved'

installed_home="${tmp_dir}/installed-home"
mkdir -p "${installed_home}" "${tmp_dir}/bin"
printf '#!/bin/sh\nexit 0\n' >"${tmp_dir}/bin/ghostty"
chmod +x "${tmp_dir}/bin/ghostty"
output="$(PATH="${tmp_dir}/bin:${PATH}" bash "${installer}" --target-home "${installed_home}" 2>&1)"
[[ "${output}" == *'Ghostty already installed'* ]]
cmp "${asset}" "${installed_home}/.config/ghostty/config.ghostty"
echo '[PASS] existing Ghostty installations skip the network installer'
