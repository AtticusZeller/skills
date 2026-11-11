#!/usr/bin/env python3
"""Deploy exact macOS assets, preserving edits and backing up replacements."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import tempfile
from datetime import datetime


def digest(data):
    return hashlib.sha256(data).hexdigest()


def deploy(asset, target, state, dry_run):
    if target.is_symlink() or (target.exists() and not target.is_file()):
        raise ValueError(f"Not a regular file: {target}")
    content = asset.read_bytes()
    current = target.read_bytes() if target.exists() else None
    previous = state.read_text().strip() if state.is_file() else None
    if current is not None and previous and digest(current) not in (previous, digest(content)):
        print(f"[MANUAL] Preserved local edits: {target}; merge {asset}")
        return
    if dry_run:
        print(f"[DRY-RUN] Deploy {asset.name} to {target}")
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    if current is not None and current != content:
        backup = target.with_name(target.name + ".bak." + datetime.now().strftime("%Y%m%d%H%M%S%f"))
        shutil.copy2(target, backup)
        print(f"[BACKUP] {backup}")
    if current != content:
        fd, name = tempfile.mkstemp(prefix=".bootstrap-", dir=target.parent)
        try:
            with os.fdopen(fd, "wb") as output:
                output.write(content)
            os.chmod(name, 0o644)
            os.replace(name, target)
        finally:
            if os.path.exists(name):
                os.unlink(name)
    state.parent.mkdir(parents=True, exist_ok=True)
    state.write_text(digest(content) + "\n")
    print(f"[OK] {target}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target-home", type=Path, default=Path.home())
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    home = args.target_home.resolve(strict=True)
    assets = Path(__file__).resolve().parent.parent / "assets"
    state = home / ".local/state/bootstrap-dev-machine"
    for asset, target, key in (
        ("zshrc.macos", home / ".zshrc", "zshrc-macos.sha256"),
        ("ghostty-config.macos.ghostty", home / "Library/Application Support/com.mitchellh.ghostty/config.ghostty", "ghostty-macos.sha256"),
    ):
        deploy(assets / asset, target, state / key, args.dry_run)


if __name__ == "__main__":
    main()
