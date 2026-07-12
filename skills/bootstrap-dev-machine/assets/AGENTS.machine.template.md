# Development Machine Agent Notes

This file records the public operational baseline installed by `bootstrap-dev-machine`. Keep credentials, private subscriptions, SSH keys, tokens, and machine-private endpoints out of this file.

## Environment Shape

- Host style: Linux GPU/DSW container. PID 1 may be `tini`, not systemd.
- Do not rely on `systemctl` or `sbc service enable`; use foreground commands or the installed `sbc-*` helpers.
- User-facing shell configuration lives in `~/.zshrc` and `~/.p10k.zsh`.

## Network and Proxy

- Primary local proxy endpoint: `{{PROXY_URL}}`.
- Keep Git HTTP/HTTPS proxy and shell proxy variables aligned with this endpoint.
- If Git reports another local proxy port, inspect and repair stale proxy configuration before retrying.

## sing-box

- Configuration: `~/.config/sing-box/config.json`.
- Use a `mixed` inbound unless the user explicitly confirms TUN support.
- Foreground diagnosis: `sbc run`.
- Background helpers: `sbc-start`, `sbc-stop`, and `sbc-status`.
- Logs and pid state live under `~/.local/state/sbc/`.

## Toolchain

- Python: uv-managed Python `{{PYTHON_VERSION}}`.
- Conda: bootstrap defaults to Miniforge at `~/miniforge3` with base auto-activation disabled; `--skip-conda` preserves an externally managed installation.
- Node: nvm-managed Node `{{NODE_VERSION}}`; source `~/.nvm/nvm.sh` in non-interactive shells.
- Agent CLIs and shared skills are installed through the public bootstrap workflow.
- Personal skills repository: `AtticusZeller/skills`.

## Validation

After environment changes, verify the relevant commands:

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

## Guardrails

- Never write tokens, private subscriptions, SSH keys, PATs, node credentials, API keys, or machine-private config into public docs or scripts.
- Prefer official installers and release artifacts.
- On DSW/tini hosts, solve service persistence with user-level scripts instead of systemd.
