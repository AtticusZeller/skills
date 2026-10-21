# System Execution Notes

## Python

- Prefer uv for Python execution and dependency management.
- Run project scripts, tests, and tools from the project root with `uv run`, for example `uv run python script.py`, `uv run pytest`, and `uv run ruff check .`.
- In uv-managed projects, use `uv add` for dependencies and `uv sync` to synchronize the environment. Avoid installing project dependencies into a global Python.
- Conda is not installed on this machine; when a project requires Conda/Mamba, ask before installing it.

## Windows Shells

- This is a Windows machine. Agent shell commands may run in Git Bash or PowerShell; check which one before using shell-specific syntax.
- In Git Bash use POSIX paths and `/dev/null`; in PowerShell use `$env:NAME`, not `$NAME`. Do not rely on `cmd.exe` syntax.
- Command-line tools come from Scoop (`~/scoop/shims`) and `~/.local/bin`; install new CLIs with `scoop install`. GUI applications come from winget.
- Do not assume `bash` on PATH is Git Bash; `C:\Windows\System32\bash.exe` belongs to WSL.
- Search files and text with `rg` when available.

## Node

- Follow the project's Node version and package manager. The default Node is on PATH for every shell; when fnm manages it, switch versions with `fnm use <version>`.

## Remote Machines (SSH)

- When managing servers from a local workstation, run Codex locally and execute remote commands through SSH; do not install or run Codex on those servers unless requested.
- Use aliases from `~/.ssh/config`; this file is the source of truth for addresses, users, ports, and keys. Record confirmed training, inference, and robot-client aliases in the local machine notes when needed.
- For remote commands, use `ssh -o BatchMode=yes -o ConnectTimeout=15 <alias> '<command>'`.
- Keep long-running training or inference services in remote `tmux` sessions so they survive SSH disconnections.

## Response Style

- 默认用中文，先给结论，再给必要依据。
- 使用短句和具体用词，只保留影响理解、判断或操作的信息。
- 避免套话、重复总结、模板化对比和不必要的结尾邀约。
- 保留原有逻辑链路，明确区分事实、推断和待核验事项。
