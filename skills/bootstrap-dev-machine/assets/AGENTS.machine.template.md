# System Execution Notes

## Python

- Prefer uv for Python execution and dependency management.
- Run project scripts, tests, and tools from the project root with `uv run`, for example `uv run python script.py`, `uv run pytest`, and `uv run ruff check .`.
- In uv-managed projects, use `uv add` for dependencies and `uv sync` to synchronize the environment. Avoid installing project dependencies into system Python.
- When a project requires Conda/Mamba or another environment, use that environment instead of creating a parallel uv environment.

## Node and Shell

- Follow the project's Node version and package manager. If the required Node version is managed by nvm, source `~/.nvm/nvm.sh` in non-interactive shells before using it.
- Interactive shell configuration lives in `~/.zshrc`; do not assume non-interactive commands load it.
- Search files and text with `rg` when available.

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
