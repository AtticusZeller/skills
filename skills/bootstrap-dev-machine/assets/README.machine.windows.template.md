# Development Machine (Windows)

This machine uses the Windows variant of the public `bootstrap-dev-machine` baseline: Scoop for command-line tools, winget for GUI applications, Git for Windows, uv/Python, Node, agent CLIs, shared skills, and sing-box-cli. Conda, zsh, and tmux are not part of the Windows baseline.

## Proxy

The expected local proxy endpoint is `{{PROXY_URL}}`. The installer sets the Git and Scoop proxies only; set shell proxy variables per session when needed:

```powershell
$env:HTTP_PROXY = '{{PROXY_URL}}'
$env:HTTPS_PROXY = '{{PROXY_URL}}'
```

Manage sing-box with `sbc config` and `sbc service` (elevated PowerShell), or `sbc run` for foreground diagnosis.

## Toolchain

- Command-line tools: `scoop install <name>`; GUI applications: `winget install --id <id> -e`.
- Python `{{PYTHON_VERSION}}` is managed by uv; uv tools live in `~/.local/bin`.
- Node `{{NODE_VERSION}}` is the default Node. When fnm manages it, its default alias is on the user PATH, so non-interactive shells see it without profile hooks.
- Git Bash comes from Git for Windows. Use WSL or SSH to a Linux host for zsh and tmux.

## Important Paths

- Scoop apps and shims: `~/scoop`
- uv tools and installers: `~/.local/bin`
- personal skills checkout: `~/skills`
- cross-agent skills: `~/.agents/skills`
- Codex skills: `~/.codex/skills`
- Claude rules and skills: `~/.claude/`

## Shared Agent Instructions

Codex loads global instructions from `~/.codex/AGENTS.md`. Claude Code shares them through `@../.codex/AGENTS.md` in `~/.claude/CLAUDE.md`. The installer preserves existing rules and adds the import only when missing. Restart Claude Code after setup and inspect `/memory` to confirm loading.

## Personal Skills

```powershell
npx skills add AtticusZeller/skills --list --full-depth
npx skills add AtticusZeller/skills --skill '*' -g -y --full-depth
```

## Verification

```powershell
sbc version
uv --version
uv python find {{PYTHON_VERSION}}
node -v
npm -v
rg --version
claude --version
gh --version
hf --version
```

Do not store tokens, private subscriptions, SSH keys, PATs, node credentials, API keys, or private machine configuration in this file.
