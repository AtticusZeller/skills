#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
installer="${script_dir}/install-herdr-config.sh"
target="${tmp_dir}/config/herdr"
bash "$installer" --config-dir "$target" --dry-run
[[ ! -e "$target" ]]
bash "$installer" --config-dir "$target"
cmp "${script_dir}/../assets/herdr-config.toml" "${target}/config.toml"
bash "$installer" --config-dir "$target"
cmp "${script_dir}/../assets/herdr-config.toml" "${target}/config.toml"
printf 'custom = true\n' > "${target}/config.toml"
bash "$installer" --config-dir "$target"
[[ "$(cat "${target}/config.toml")" == 'custom = true' ]]
printf '[PASS] Herdr config fidelity, dry run, idempotency and preservation\n'
