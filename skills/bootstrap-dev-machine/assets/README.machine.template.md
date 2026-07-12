# Development Machine

This machine uses the public `bootstrap-dev-machine` baseline: uv/Python, Miniforge/conda, nvm/Node, shell tooling, agent CLIs, shared skills, and non-systemd sing-box helpers.

## Quick Start

Start and inspect the local proxy:

```bash
sbc-start
sbc-status
```

The expected proxy endpoint is `{{PROXY_URL}}`. Stop the background process with:

```bash
sbc-stop
```

Use `sbc run` for foreground diagnosis.

## Toolchain

- Python `{{PYTHON_VERSION}}` is managed by uv.
- Conda defaults to Miniforge at `~/miniforge3`; `--skip-conda` keeps an externally managed installation instead.
- Node `{{NODE_VERSION}}` is managed by nvm.
- Load nvm before using Node in non-interactive shells:

```bash
source "$HOME/.nvm/nvm.sh"
node -v
npm -v
```

## Important Paths

- sing-box config: `~/.config/sing-box/config.json`
- sing-box helpers: `~/.local/bin/sbc-start`, `sbc-stop`, `sbc-status`
- sing-box state: `~/.local/state/sbc/`
- default Miniforge prefix: `~/miniforge3`
- personal skills checkout: `~/skills`
- cross-agent skills: `~/.agents/skills`
- Codex skills: `~/.codex/skills`
- Claude rules and skills: `~/.claude/`

## Personal Skills

```bash
npx skills add AtticusZeller/skills --list --full-depth
npx skills add AtticusZeller/skills --skill '*' -g -y --full-depth
```

## Verification

```bash
sbc version
sbc-status
uv --version
uv python find {{PYTHON_VERSION}}
conda --version
bash -lc 'source "$HOME/.nvm/nvm.sh" && node -v && npm -v'
claude --version
gh --version
hf --version
```

Do not store tokens, private subscriptions, SSH keys, PATs, node credentials, API keys, or private machine configuration in this file.
