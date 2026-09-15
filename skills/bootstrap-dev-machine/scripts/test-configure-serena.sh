#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT

config="$test_root/serena_config.yml"

python3 - "$config" <<'PY'
import pathlib
import sys

pathlib.Path(sys.argv[1]).write_text(
    "language_backend: LSP\n"
    "web_dashboard: true\n"
    "web_dashboard_open_on_launch: true\n"
    "base_modes:\n"
    "- interactive\n"
    "- editing\n"
    "default_modes:\n"
    "registered_projects:\n"
    "- /example/project\n"
    "project_serena_folder_location: $projectDir/.serena\n"
    "custom_setting: keep-me\n"
)
PY

bash "$script_dir/configure-serena.sh" "$config" >/dev/null
first_hash="$(sha256sum "$config" | cut -d' ' -f1)"
bash "$script_dir/configure-serena.sh" "$config" >/dev/null
second_hash="$(sha256sum "$config" | cut -d' ' -f1)"

[[ "$first_hash" == "$second_hash" ]]
grep -Fxq 'web_dashboard: false' "$config"
grep -Fxq 'web_dashboard_open_on_launch: false' "$config"
grep -Fxq '  - no-memories' "$config"
grep -Fxq 'registered_projects:' "$config"
grep -Fxq -- '- /example/project' "$config"
grep -Fxq 'custom_setting: keep-me' "$config"

python3 - "$config" <<'PY'
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text()
assert "base_modes:\n  - interactive\n  - editing\n  - no-memories\ndefault_modes:" in text
PY

printf '[PASS] Serena global configuration is valid, preserving, and idempotent\n'
