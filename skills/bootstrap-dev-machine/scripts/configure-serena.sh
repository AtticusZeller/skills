#!/usr/bin/env bash
set -euo pipefail

config_path="${1:-$HOME/.serena/serena_config.yml}"

if [[ ! -f "$config_path" ]]; then
  printf 'Serena config not found: %s\n' "$config_path" >&2
  printf 'Run `serena init` first.\n' >&2
  exit 1
fi

python3 - "$config_path" "$HOME" <<'PY'
import os
import pathlib
import sys
import tempfile

path = pathlib.Path(sys.argv[1])
home = sys.argv[2]
lines = path.read_text().splitlines(keepends=True)
updates = {
    "language_backend": ["language_backend: LSP\n"],
    "web_dashboard": ["web_dashboard: false\n"],
    "web_dashboard_open_on_launch": ["web_dashboard_open_on_launch: false\n"],
    "base_modes": [
        "base_modes:\n",
        "  - interactive\n",
        "  - editing\n",
        "  - no-memories\n",
    ],
    "project_serena_folder_location": [
        f'project_serena_folder_location: "{home}/.serena/projects/$projectFolderName/.serena"\n'
    ],
}

result = []
seen = set()
i = 0
while i < len(lines):
    line = lines[i]
    if line[:1] not in (" ", "\t", "#", "\n", "\r") and ":" in line:
        key = line.split(":", 1)[0]
        if key in updates:
            if key not in seen:
                result.extend(updates[key])
                seen.add(key)
            i += 1
            while i < len(lines):
                next_line = lines[i]
                if next_line.startswith((" ", "\t")) or not next_line.strip():
                    i += 1
                    continue
                break
            continue
    result.append(line)
    i += 1

if missing := updates.keys() - seen:
    if result and result[-1].strip():
        result.append("\n")
    for key in updates:
        if key in missing:
            result.extend(updates[key])

new_text = "".join(result)
if new_text != path.read_text():
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as handle:
            handle.write(new_text)
        os.chmod(temp_name, path.stat().st_mode)
        os.replace(temp_name, path)
    except BaseException:
        try:
            os.unlink(temp_name)
        except FileNotFoundError:
            pass
        raise

print(f"Configured Serena global baseline: {path}")
PY
