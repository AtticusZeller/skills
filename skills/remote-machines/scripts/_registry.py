"""Machine registry loading and remote command composition shared by the remote-machines scripts.

Everything here is pure (no SSH, no subprocess) except `run`, so the composition rules can be
regression-tested against a fixture registry.
"""

from __future__ import annotations

import getpass
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Any

import yaml

REGISTRY_ENV = "REMOTE_MACHINES_DIR"
DEFAULT_REGISTRY = "~/.config/remote-machines/machines"
SSH_OPTS = ["-T", "-o", "BatchMode=yes", "-o", "ConnectTimeout=15"]
HISTORY_OFF = "unset HISTFILE; set +o history"
NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")

# Static fields only. Dynamic state (GPU memory, disk usage, jobs, git state) and secrets are
# rejected by omission: an unknown key fails loudly instead of silently entering the registry.
ALLOWED_KEYS = {
    "alias", "extends", "org", "role", "network", "reach", "hardware", "tools", "repos",
    "work_root", "envs", "dirs", "history_off", "shared", "shared_rules", "risk", "confirm_ops",
    "owner", "notes", "todo",
}
ROLES = {"train", "infer", "robot", "other"}
RISKS = {"normal", "high"}


class RegistryError(SystemExit):
    """Raised for registry problems; exits with a readable message instead of a traceback."""

    def __init__(self, message: str) -> None:
        super().__init__(f"remote-machines: {message}")


def registry_dir() -> Path:
    return Path(os.environ.get(REGISTRY_ENV, DEFAULT_REGISTRY)).expanduser()


def _read_yaml(path: Path) -> dict[str, Any]:
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict):
        raise RegistryError(f"{path} must contain a mapping")
    return data


def deep_merge(base: dict[str, Any], over: dict[str, Any]) -> dict[str, Any]:
    """Merge mappings by key recursively; scalars and lists in `over` replace those in `base`."""
    merged = dict(base)
    for key, value in over.items():
        if isinstance(value, dict) and isinstance(merged.get(key), dict):
            merged[key] = deep_merge(merged[key], value)
        else:
            merged[key] = value
    return merged


def validate(machine: dict[str, Any], source: str) -> None:
    unknown = set(machine) - ALLOWED_KEYS
    if unknown:
        raise RegistryError(f"{source}: unknown keys {sorted(unknown)} (see references/schema.md)")
    if machine.get("role", "other") not in ROLES:
        raise RegistryError(f"{source}: role must be one of {sorted(ROLES)}")
    if machine.get("risk", "normal") not in RISKS:
        raise RegistryError(f"{source}: risk must be one of {sorted(RISKS)}")


def load_machine(alias: str, root: Path | None = None) -> dict[str, Any]:
    """Return the effective entry: `_defaults.yaml`, then each `extends` file, then `<alias>.yaml`."""
    root = root or registry_dir()
    path = root / f"{alias}.yaml"
    if not path.is_file():
        raise RegistryError(f"no registry entry {path}; run scripts/bootstrap {alias}")
    own = _read_yaml(path)
    validate(own, str(path))
    merged: dict[str, Any] = {}
    defaults = root / "_defaults.yaml"
    if defaults.is_file():
        merged = _read_yaml(defaults)
    parents = own.get("extends") or []
    for parent in [parents] if isinstance(parents, str) else parents:
        parent_path = root / f"{parent}.yaml"
        if not parent_path.is_file():
            raise RegistryError(f"{path}: extends missing file {parent_path}")
        merged = deep_merge(merged, _read_yaml(parent_path))
    merged = deep_merge(merged, own)
    merged["alias"] = alias
    validate(merged, f"{alias} (merged)")
    return merged


def list_aliases(root: Path | None = None) -> list[str]:
    root = root or registry_dir()
    return sorted(p.stem for p in root.glob("*.yaml") if not p.stem.startswith("_"))


def check_name(name: str, what: str) -> str:
    if not NAME_RE.match(name):
        raise RegistryError(f"invalid {what} {name!r}: use letters, digits, '.', '_' or '-'")
    return name


def qpath(path: str) -> str:
    """Shell-quote a path while keeping a leading `~/` expandable on the remote side."""
    if path == "~":
        return "~"
    if path.startswith("~/"):
        return "~/" + shlex.quote(path[2:])
    return shlex.quote(path)


def owner(machine: dict[str, Any]) -> str:
    return str(machine.get("owner") or getpass.getuser())


def repo_entry(machine: dict[str, Any], repo: str) -> dict[str, Any]:
    repos = machine.get("repos") or {}
    if repo not in repos:
        raise RegistryError(f"{machine['alias']}: unknown repo {repo!r}; known: {sorted(repos)}")
    entry = repos[repo]
    return {"path": entry} if isinstance(entry, str) else dict(entry)


def work_copy(machine: dict[str, Any], repo: str, task: str) -> str:
    root = machine.get("work_root")
    if not root:
        raise RegistryError(f"{machine['alias']}: --task needs work_root in the registry")
    return f"{root}/{check_name(task, 'task')}/{repo}"


def workdir(machine: dict[str, Any], repo: str | None, task: str | None) -> str | None:
    """Directory a command runs in: the task's own work copy if `task` is set, else the repo path."""
    if repo is None:
        if task is not None:
            raise RegistryError("--task needs --repo")
        return None
    entry = repo_entry(machine, repo)
    return work_copy(machine, repo, task) if task else entry["path"]


def env_commands(machine: dict[str, Any], envs: list[str]) -> list[str]:
    table = machine.get("envs") or {}
    missing = [e for e in envs if e not in table]
    if missing:
        raise RegistryError(f"{machine['alias']}: unknown envs {missing}; known: {sorted(table)}")
    return [table[e] for e in envs]


def history_prefix(machine: dict[str, Any]) -> str:
    return f"{HISTORY_OFF}; " if machine.get("history_off") else ""


def compose(
    machine: dict[str, Any],
    cmd: str,
    repo: str | None = None,
    task: str | None = None,
    envs: list[str] | None = None,
) -> str:
    """Build the bash script body: cd into the workdir, activate envs in order, then run `cmd`."""
    steps = []
    directory = workdir(machine, repo, task)
    if directory:
        steps.append(f"cd {qpath(directory)}")
    steps.extend(env_commands(machine, envs or []))
    steps.append(cmd)
    return " && ".join(steps)


def remote(machine: dict[str, Any], script: str) -> str:
    """Wrap a script so it runs under bash regardless of the account's login shell (zsh, sh)."""
    return "bash -c " + shlex.quote(history_prefix(machine) + script)


def ssh_argv(alias: str, remote_cmd: str) -> list[str]:
    return ["ssh", *SSH_OPTS, alias, remote_cmd]


def risk_notice(machine: dict[str, Any]) -> None:
    if machine.get("risk") == "high":
        ops = ", ".join(machine.get("confirm_ops") or [])
        print(f"[remote-machines] {machine['alias']} is risk: high; confirm first: {ops}", file=sys.stderr)


def run(argv: list[str], dry_run: bool, capture: bool = False) -> subprocess.CompletedProcess[str]:
    if dry_run:
        print(shlex.join(argv))
        return subprocess.CompletedProcess(argv, 0, "", "")
    return subprocess.run(argv, text=True, capture_output=capture, check=False)


def split_command(argv: list[str]) -> tuple[list[str], str]:
    """Split CLI args at the first `--`; everything after it is the remote command, verbatim."""
    if "--" not in argv:
        return argv, ""
    i = argv.index("--")
    return argv[:i], " ".join(argv[i + 1 :])
