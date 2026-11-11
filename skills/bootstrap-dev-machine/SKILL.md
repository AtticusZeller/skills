---
name: bootstrap-dev-machine
description: Configure a Linux GPU/DSW development machine, a macOS/MacBook workstation with Homebrew, or Windows through PowerShell. Includes ripgrep, Codex, uv/Python 3.12, Miniforge/conda/mamba, Claude Code, nvm/Node 24, Context7, shared skills, zsh/tmux, Ghostty, Git/GitHub/Hugging Face tooling, and shared agent instructions. Use when bootstrapping, reproducing, migrating, auditing, or repairing this development environment on a new machine.
---

# Bootstrap Dev Machine

## Overview

Use this skill to rebuild the development-machine baseline on Linux GPU/DSW, macOS/MacBook, or Windows. The normal path is one idempotent installer run followed by one review of its validation and manual-follow-up summary.

On macOS, read `references/macos-bootstrap.md` and run `bash scripts/bootstrap-dev-machine-macos.sh` (preview with `--dry-run`). This uses Homebrew, `/bin/zsh`, Mac-specific Ghostty/zsh assets, and proxy opt-in. Never run the Linux bootstrap on a Mac. Add `--set-default-terminal` only when the user requested Ghostty's default-terminal associations.

On Windows, run `powershell -ExecutionPolicy Bypass -File scripts/bootstrap-dev-machine.ps1` (add `-DryRun` to preview) from a non-elevated PowerShell and read `references/windows-bootstrap.md` instead of the Linux workflow below.

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
- Keep `~/.codex/AGENTS.md` focused on execution defaults, configuration paths, host-specific operational notes, and the shared response and writing style in the machine template. Apply that style to answers, explanations, and documents; keep it separate from code implementation and development workflow rules. Keep installation walkthroughs and validation commands in `~/README.md` or scripts; do not add generic collaboration rules or duplicate unrelated Skill instructions.
- The Linux machine template's `Remote Machines (SSH)` section points to the `remote-machines` skill. Host facts belong in its local registry `~/.config/remote-machines/machines/`; keep machine-private connection details out of the public templates. The Windows template keeps plain SSH rules because the remote-machines scripts are verified on Linux only.
- Let `scripts/install-machine-handoff.sh` create the public machine handoff from bundled templates. Never recreate or summarize those templates manually; preserve existing handoff files unchanged.
- The installer creates `~/.codex/AGENTS.md` only when absent and adds one import to `~/.claude/CLAUDE.md`, preserving existing Claude rules. Both tools share the Codex global file. Do not hardcode a workstation username. Restart Claude Code after setup and inspect `/memory` to confirm loading.
- Keep executable setup logic in `scripts/` or `assets/`; Markdown should explain inputs, boundaries, and recovery rather than duplicate command sequences.
- Start interactive tmux servers from a real terminal. For missing application colours, inspect inherited `NO_COLOR`, `TERM`, and `COLORTERM` using `references/tmux-baseline.md`; preserve intentional colour preferences.
- Deploy the Ghostty configuration from `assets/ghostty-config.ghostty`; install Ghostty on apt/dpkg hosts with the documented ghostty-ubuntu installer command only when it is absent. Preserve locally edited configurations and treat unsupported hosts or installer failures as warnings, not blockers.
- Keep the DSW persistent-storage prompt opt-in; its installer must back up an existing Codex `AGENTS.md` and append the asset exactly once.

## Resources

- `scripts/bootstrap-dev-machine.sh`: idempotent one-shot installer and primary entry point.
- `scripts/bootstrap-dev-machine-macos.sh` and `scripts/check-dev-machine-macos.sh`: Homebrew-based MacBook installer and read-only checker.
- `scripts/install-macos-config.py`: deterministic Mac zsh/Ghostty asset deployer with backups and local-edit preservation.
- `scripts/install-prompt-config.sh` and `scripts/test-prompt-config.sh`: shared Powerlevel10k preset deployment and fidelity/preservation checks; existing personal prompts are preserved.
- `scripts/set-default-terminal-macos.swift`: explicit opt-in default application associations; `--check` verifies without changing them.
- `scripts/test-macos-bootstrap.sh`: Mac asset deployment, idempotency, backup, local-edit, and handoff regression checks.
- `scripts/check-dev-machine.sh`: read-only validation script used by the installer.
- `scripts/bootstrap-dev-machine.ps1` and `scripts/check-dev-machine.ps1`: Windows installer (Scoop CLIs, winget GUI apps, no Conda/zsh/tmux) and its read-only validation.
- `scripts/test-windows-bootstrap.sh`: Windows installer regression checks; PowerShell parse checks run when PowerShell is available.
- `scripts/install-tmux-baseline.sh`: idempotent Oh my tmux installer; run it directly for a tmux-only repair. Keeps local customizations and never stops sessions.
- `scripts/install-ghostty-terminal.sh`: idempotent Ghostty installer and config deployer; supports `--target-home`, `--skip-install`, and `--dry-run`, and preserves locally edited configs.
- `scripts/install-machine-handoff.sh`: deterministic installer for machine handoff and shared Codex/Claude global instructions; supports `--target-home` and `--dry-run` for focused configuration.
- `scripts/install-dsw-persistent-prompt.sh`: optional, idempotent installer for the Alibaba Cloud DSW rule in `~/.codex/AGENTS.md`.
- `references/bootstrap-phases.md`: installer inputs, automated phases, manual boundaries, and failure handling.
- `references/windows-bootstrap.md`: Windows inputs, phases, boundaries, and recovery.
- `references/macos-bootstrap.md`: MacBook inputs, tools, shell configuration, default terminal, and recovery.
- `references/sbc-service-scripts.md`: behavior and configuration boundaries for the deployed sing-box helpers.
- `references/zsh-baseline.md`: resulting shell state and focused startup diagnosis.
- `references/tmux-baseline.md`: Oh my tmux paths, customization, and session-preserving reload.
- `references/ghostty-baseline.md`: Ghostty installer command, supported distributions, configuration path, and local-change recovery.
- `assets/zshrc.server`: reusable public server `.zshrc` template with proxy, CUDA, uv, conda/mamba, NVM, PATH, and virtualenv defaults.
- `assets/zshrc.macos` and `assets/ghostty-config.macos.ghostty`: Mac-specific shell and terminal templates.
- `assets/p10k.zsh`: exported Ubuntu Powerlevel10k preset (lean, two lines, left frame, transient prompt, Nerd Font v3), reused on Mac as `~/.p10k.zsh` without the wizard.
- `assets/tmux-defaults.conf`: mouse support and right-click menus enabled on fresh tmux installations.
- `assets/ghostty-config.ghostty`: Ghostty 1.3+ configuration template deployed to `$XDG_CONFIG_HOME/ghostty/config.ghostty`.
- `assets/{AGENTS,README}.machine[.macos|.windows].template.md`: public machine handoff templates rendered by the installer (`--platform macos` or `--platform windows` selects the corresponding set).
- `assets/winget-apps.txt`: winget GUI application IDs; command-line tools belong in Scoop.
- `assets/sbc-{start,stop,status}`: executable user-level sing-box helpers for non-systemd hosts.

## Completion Criteria

The machine is ready when the user can run `rg`, `mamba --version`, `sbc version`, use the local proxy, start the configured zsh, Ghostty, and Oh my tmux baselines without errors, run Codex/Claude, use Node 24 through nvm, use uv Python 3.12, manage environments with `conda` and `mamba`, and read `~/.codex/AGENTS.md` plus `~/README.md` for handoff details. Claude Code must import the shared global instructions from `~/.claude/CLAUDE.md`.
