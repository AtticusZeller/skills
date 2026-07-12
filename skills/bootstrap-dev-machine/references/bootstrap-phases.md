# Bootstrap Phases

Use these phases to configure a fresh Linux GPU/DSW-style development machine. Verify each phase before continuing.

## Phase 0: Network And SSH Proxy

Confirm the user has exposed a local HTTP proxy on `127.0.0.1:7890`, commonly via SSH forwarding or an existing local proxy.

Set shell proxy variables when network access is needed:

```bash
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
export HTTP_PROXY=http://127.0.0.1:7890
export HTTPS_PROXY=http://127.0.0.1:7890
```

Configure Git to use the same proxy:

```bash
git config --global http.proxy http://127.0.0.1:7890
git config --global https.proxy http://127.0.0.1:7890
```

If Git still reports `127.0.0.1:8118`, remove or replace stale global proxy settings before retrying.

## Phase 1: Codex Entry Point

Install or start Codex only after the proxy path is working. Verify network and Git before installing large toolchains:

```bash
curl -I https://github.com
git ls-remote https://github.com/nvm-sh/nvm HEAD
```

When sandboxed network commands fail with DNS, connect, or registry errors, rerun the same important command with the required approval/escalation rather than changing mirrors blindly.

## Phase 2: uv, Python, And sing-box

Install uv from the official installer if missing:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Install Python 3.12:

```bash
uv python install 3.12
uv python find 3.12
```

Install sing-box-cli with official PyPI if a mirror is broken:

```bash
env -u UV_DEFAULT_INDEX -u PIP_INDEX_URL \
  uv tool install --python 3.12 --default-index https://pypi.org/simple sing-box-cli
```

Use sing-box `mixed` inbound in DSW/tini hosts. Avoid TUN mode unless the user confirms the host supports route and network permissions.

## Phase 3: sing-box Persistence

Do not use `sbc service enable` on hosts where PID 1 is `tini` or `systemctl` is missing. Use the `sbc-*` model described in `sbc-service-scripts.md`.

Expected commands:

```bash
sbc-start
sbc-status
sbc-stop
```

Verify proxy operation with:

```bash
curl -I --proxy http://127.0.0.1:7890 https://www.google.com
```

## Phase 4: Agent Tooling

Install Claude Code:

```bash
curl -fsSL https://claude.ai/install.sh | bash
claude --version
```

Install nvm and Node 24:

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.5/install.sh | bash
. "$HOME/.nvm/nvm.sh"
nvm install 24
node -v
npm -v
```

Install Context7 and global skills as requested by the user. Prefer non-interactive Context7 setup after login:

```bash
npx ctx7 setup --cli --claude --codex -y
```

Install the personal skills repository for future reuse:

```bash
npx skills add AtticusZeller/skills --list --full-depth
npx skills add AtticusZeller/skills --skill bootstrap-dev-machine -g -y --full-depth
npx skills add AtticusZeller/skills --skill manage-personal-skills -g -y --full-depth
npx skills add AtticusZeller/skills --skill init-repo-agents -g -y --full-depth
npx skills add AtticusZeller/skills --skill git-fork-workflow -g -y --full-depth
```

If `/root/skills` is checked out, reinstall the usual external global skills from its manifest:

```bash
cd /root/skills
bash scripts/install-global-skills.sh
```

## Phase 5: Developer CLI Baseline

Install or verify:

```text
zsh tmux bat fzf ripgrep fd tree htop jq ffmpeg
gh hf cc-switch nvitop wandb
```

Use official release artifacts when official apt repositories are slow or blocked. Keep nvm-managed Node as the source of truth unless the user requests system symlinks.

## Phase 6: Handoff Docs

Create or update:

```text
/root/AGENTS.md
/root/README.md
/root/skills
```

`AGENTS.md` is for future agents and should contain operational rules, paths, guardrails, and validation commands. `README.md` is for the user and should explain how to use the configured machine.

Never include secrets, tokens, private subscriptions, SSH keys, or account credentials in either file.

## Phase 7: Final Validation

Run the read-only checker:

```bash
bash /root/.codex/skills/bootstrap-dev-machine/scripts/check-dev-machine.sh
```

Also verify:

```bash
sbc version
uv --version
bash -lc 'source "$HOME/.nvm/nvm.sh" && node -v && npm -v'
claude --version
gh --version
hf --version
npx ctx7 --version
```
