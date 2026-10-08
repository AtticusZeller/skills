---
name: bootstrap-dev-machine
description: Guide a Codex agent through configuring a fresh GPU/DSW-style Linux development machine with SSH-forwarded proxy, ripgrep, Codex, uv/Python 3.12, Miniforge/conda/mamba, sing-box mixed proxy, Claude Code, nvm/Node 24, Context7, global development skills, zsh/tmux, Git/GitHub/Hugging Face tooling, and root-level AGENTS.md/README.md handoff docs. Use when the user asks to bootstrap, reproduce, migrate, audit, or repair this development environment on a new machine.
---

# Bootstrap Dev Machine

## Overview

Use this skill to rebuild the same development-machine baseline on a fresh Linux GPU/DSW host. The normal path is one idempotent installer run followed by one review of its validation and manual-follow-up summary.

## Workflow

1. Confirm the host shape: user, shell, PID 1, package manager, writable home, and whether `127.0.0.1:7890` is reachable.
2. Preview once with `bash scripts/bootstrap-dev-machine.sh --dry-run` when the host is unfamiliar or already configured.
3. Run `bash scripts/bootstrap-dev-machine.sh` once. On Alibaba Cloud DSW, add `--enable-dsw-persistent-prompt` to append the persistent-storage rule to `~/.codex/AGENTS.md`. Prefer environment variables or its skip flags over manually replaying phase commands.
4. Inspect the final validation and consolidated manual-follow-up list.
5. Read `references/bootstrap-phases.md` only for inputs, phase boundaries, or a failed phase. Read the focused zsh or sing-box reference only when that subsystem needs diagnosis or customization.

## Rules

- Do not write tokens, PATs, SSH keys, private subscriptions, node credentials, or API keys into docs or scripts.
- Do not use `systemctl` as the primary persistence mechanism on DSW/tini hosts.
- Keep sing-box in `mixed` mode unless the user explicitly asks for TUN and confirms the host supports it.
- Keep Git proxy, shell proxy variables, and install commands aligned to the user's active proxy endpoint.
- Prefer official installers or official release artifacts. If a mirror fails with 403 or stale packages, override it explicitly rather than debugging the wrong layer.
- Keep machine `AGENTS.md` focused on execution defaults, configuration paths, and host-specific operational notes. Keep installation walkthroughs and validation commands in `README.md` or scripts; do not add generic collaboration rules or duplicate unrelated Skill instructions.
- The machine template includes `Remote Machines (SSH)` for workstations that manage training, inference, or robot servers. Add confirmed host aliases only to local machine notes; keep machine-private connection details out of the public template.
- Let `scripts/install-machine-handoff.sh` create the public machine handoff from bundled templates. Never recreate or summarize those templates manually; preserve existing handoff files unchanged.
- The same installer creates `~/.codex/AGENTS.md` only when absent and adds an import to `~/.claude/CLAUDE.md`, preserving existing Claude rules. Both tools share the Codex global file; do not hardcode a workstation username. Restart Claude Code after setup and inspect `/memory` to confirm loading.
- Keep executable setup logic in `scripts/` or `assets/`; Markdown should explain inputs, boundaries, and recovery rather than duplicate command sequences.
- Start interactive tmux servers from a real terminal. For missing application colours, inspect inherited `NO_COLOR`, `TERM`, and `COLORTERM` using `references/tmux-baseline.md`; preserve intentional colour preferences.
- Keep the DSW persistent-storage prompt opt-in; its installer must back up an existing Codex `AGENTS.md` and append the asset exactly once.

## Resources

- `scripts/bootstrap-dev-machine.sh`: idempotent one-shot installer and primary entry point.
- `scripts/check-dev-machine.sh`: read-only validation script used by the installer.
- `scripts/install-tmux-baseline.sh`: idempotent Oh my tmux installer; run it directly for a tmux-only repair. Keeps local customizations and never stops sessions.
- `scripts/install-machine-handoff.sh`: deterministic installer for machine handoff and shared Codex/Claude global instructions; supports `--target-home` and `--dry-run` for focused configuration.
- `scripts/install-dsw-persistent-prompt.sh`: optional, idempotent installer for the Alibaba Cloud DSW rule in `~/.codex/AGENTS.md`.
- `references/bootstrap-phases.md`: installer inputs, automated phases, manual boundaries, and failure handling.
- `references/sbc-service-scripts.md`: behavior and configuration boundaries for the deployed sing-box helpers.
- `references/zsh-baseline.md`: resulting shell state and focused startup diagnosis.
- `references/tmux-baseline.md`: Oh my tmux paths, customization, and session-preserving reload.
- `assets/zshrc.server`: reusable public server `.zshrc` template with proxy, CUDA, uv, conda/mamba, NVM, PATH, and virtualenv defaults.
- `assets/tmux-defaults.conf`: mouse support and right-click menus enabled on fresh tmux installations.
- `assets/{AGENTS,README}.machine.template.md`: public machine handoff templates rendered by the installer.
- `assets/sbc-{start,stop,status}`: executable user-level sing-box helpers for non-systemd hosts.

## Completion Criteria

The machine is ready when the user can run `rg`, `mamba --version`, `sbc version`, use the local proxy, start the configured zsh and Oh my tmux baselines without errors, run Codex/Claude, use Node 24 through nvm, use uv Python 3.12, manage environments with `conda` and `mamba`, and read `/root/AGENTS.md` plus `/root/README.md` for handoff details.
