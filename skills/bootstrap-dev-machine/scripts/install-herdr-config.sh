#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_dir="${HOME}/.config/herdr"
dry_run=false
while (($#)); do
  case "$1" in
    --config-dir) config_dir="$2"; shift 2 ;;
    --dry-run) dry_run=true; shift ;;
    *) printf '[ERROR] Unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
done
destination="${config_dir}/config.toml"
if [[ -e "$destination" || -L "$destination" ]]; then
  printf '[INFO] Preserved existing %s\n' "$destination"
elif [[ "$dry_run" == true ]]; then
  printf '[INFO] Would install %s\n' "$destination"
else
  mkdir -p "$config_dir"
  install -m 0644 "${script_dir}/../assets/herdr-config.toml" "$destination"
  printf '[INFO] Installed %s\n' "$destination"
fi
