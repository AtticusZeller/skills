---
name: bootstrap-dev-machine
description: Guide a Codex agent through configuring a fresh GPU/DSW-style Linux development machine with SSH-forwarded proxy, Codex, uv/Python 3.12, sing-box mixed proxy, Claude Code, nvm/Node 24, Context7, global development skills, zsh/tmux, Git/GitHub/Hugging Face tooling, and root-level AGENTS.md/README.md handoff docs. Use when the user asks to bootstrap, reproduce, migrate, audit, or repair this development environment on a new machine.
---

# Bootstrap Dev Machine

## Overview

Use this skill to rebuild the same development-machine baseline on a fresh Linux GPU/DSW host. The normal path is one idempotent installer run followed by one review of its validation and manual-follow-up summary.

## Workflow

1. Confirm the host shape: user, shell, PID 1, package manager, writable home, and whether `127.0.0.1:7890` is reachable.
2. Preview once with `bash scripts/bootstrap-dev-machine.sh --dry-run` when the host is unfamiliar or already configured.
3. Run `bash scripts/bootstrap-dev-machine.sh` once. Prefer environment variables or its skip flags over manually replaying phase commands.
4. Inspect the final validation and consolidated manual-follow-up list.
5. Read `references/bootstrap-phases.md` only for inputs, phase boundaries, or a failed phase. Read the focused zsh or sing-box reference only when that subsystem needs diagnosis or customization.

## Rules

- Do not write tokens, PATs, SSH keys, private subscriptions, node credentials, or API keys into docs or scripts.
- Do not use `systemctl` as the primary persistence mechanism on DSW/tini hosts.
- Keep sing-box in `mixed` mode unless the user explicitly asks for TUN and confirms the host supports it.
- Keep Git proxy, shell proxy variables, and install commands aligned to the user's active proxy endpoint.
- Prefer official installers or official release artifacts. If a mirror fails with 403 or stale packages, override it explicitly rather than debugging the wrong layer.
- Keep `/root/AGENTS.md` for agents and `/root/README.md` for users; do not mix operational rules with user-facing walkthroughs.
- Keep executable setup logic in `scripts/` or `assets/`; Markdown should explain inputs, boundaries, and recovery rather than duplicate command sequences.

## Resources

- `scripts/bootstrap-dev-machine.sh`: idempotent one-shot installer and primary entry point.
- `scripts/check-dev-machine.sh`: read-only validation script used by the installer.
- `references/bootstrap-phases.md`: installer inputs, automated phases, manual boundaries, and failure handling.
- `references/sbc-service-scripts.md`: behavior and configuration boundaries for the deployed sing-box helpers.
- `references/zsh-baseline.md`: resulting shell state and focused startup diagnosis.
- `assets/zshrc.server`: reusable public server `.zshrc` template with proxy, CUDA, uv, NVM, PATH, and virtualenv defaults.
- `assets/sbc-{start,stop,status}`: executable user-level sing-box helpers for non-systemd hosts.

## Completion Criteria

The machine is ready when the user can run `sbc version`, use the local proxy, start the configured zsh baseline without errors, run Codex/Claude, use Node 24 through nvm, use uv Python 3.12, and read `/root/AGENTS.md` plus `/root/README.md` for handoff details.
