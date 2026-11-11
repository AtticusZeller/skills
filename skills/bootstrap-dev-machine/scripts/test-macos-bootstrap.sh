#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash -n "$script_dir/bootstrap-dev-machine-macos.sh"
bash -n "$script_dir/check-dev-machine-macos.sh"
if command -v uv >/dev/null 2>&1; then
  python_command=(uv run --python 3.12 python)
else
  python_command=(python3)
fi
"${python_command[@]}" - "$script_dir" <<'PY'
from pathlib import Path
import subprocess
import sys
import tempfile

scripts = Path(sys.argv[1])
assets = scripts.parent / 'assets'
helper = scripts / 'install-macos-config.py'
with tempfile.TemporaryDirectory() as temp:
    home = Path(temp) / 'home with spaces'
    home.mkdir()
    command = [sys.executable, str(helper), '--target-home', str(home)]
    subprocess.run(command + ['--dry-run'], check=True)
    assert not list(home.iterdir()), 'dry run wrote files'
    shell = home / '.zshrc'
    ghostty = home / 'Library/Application Support/com.mitchellh.ghostty/config.ghostty'
    shell.write_text('# previous shell\n')
    subprocess.run(command, check=True)
    assert shell.read_bytes() == (assets / 'zshrc.macos').read_bytes()
    assert ghostty.read_bytes() == (assets / 'ghostty-config.macos.ghostty').read_bytes()
    assert shell.stat().st_mode & 0o777 == 0o644
    backups = list(home.glob('.zshrc.bak.*'))
    assert len(backups) == 1 and backups[0].read_text() == '# previous shell\n'
    subprocess.run(command, check=True)
    assert list(home.glob('.zshrc.bak.*')) == backups, 'rerun created a redundant backup'
    shell.write_text(shell.read_text() + '# local change\n')
    edited = shell.read_bytes()
    subprocess.run(command, check=True)
    assert shell.read_bytes() == edited, 'overwrote local edits'
    ghostty.unlink()
    ghostty.symlink_to(shell)
    assert subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode != 0
    assert ghostty.is_symlink() and shell.read_bytes() == edited
    subprocess.run(['bash', str(scripts / 'install-machine-handoff.sh'), '--target-home', str(home), '--platform', 'macos', '--proxy-url', 'disabled'], check=True)
    for name, path in [('AGENTS', home / '.codex/AGENTS.md'), ('README', home / 'README.md')]:
        expected = (assets / f'{name}.machine.macos.template.md').read_text().replace('{{PYTHON_VERSION}}', '3.12').replace('{{NODE_VERSION}}', '24').replace('{{PROXY_URL}}', 'disabled')
        assert path.read_text() == expected
    shared = home / '.claude/CLAUDE.md'
    previous = shared.read_bytes()
    subprocess.run(['bash', str(scripts / 'install-machine-handoff.sh'), '--target-home', str(home), '--platform', 'macos'], check=True)
    assert shared.read_bytes() == previous, 'duplicated Claude import'
print('[PASS] macOS asset fidelity, backups, idempotency, edit preservation, symlink refusal, and shared handoff')
PY
if [[ "$(uname -s)" == Darwin ]]; then
  /bin/zsh -n "$script_dir/../assets/zshrc.macos"
  if [[ -x /Applications/Ghostty.app/Contents/MacOS/ghostty ]]; then
    /Applications/Ghostty.app/Contents/MacOS/ghostty +validate-config --config-file="$script_dir/../assets/ghostty-config.macos.ghostty"
  fi
fi
