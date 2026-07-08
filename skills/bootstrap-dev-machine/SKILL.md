---
name: bootstrap-dev-machine
description: Guide a Codex agent through configuring a fresh GPU/DSW-style Linux development machine with SSH-forwarded proxy, Codex, uv/Python 3.12, sing-box mixed proxy, Claude Code, nvm/Node 24, Context7, global development skills, zsh/tmux, Git/GitHub/Hugging Face tooling, and root-level AGENTS.md/README.md handoff docs. Use when the user asks to bootstrap, reproduce, migrate, audit, or repair this development environment on a new machine.
---

# Bootstrap Dev Machine

## Overview

Use this skill to rebuild the same development-machine baseline on a fresh Linux GPU/DSW host. Treat the workflow as staged and verifiable: establish network/proxy first, install agent tooling second, configure sing-box and developer CLIs third, then write handoff docs and validate.

## Workflow

1. Confirm the host shape: user, shell, PID 1, package manager, writable home, and whether `127.0.0.1:7890` is reachable.
2. Read `references/bootstrap-phases.md` before installing or changing anything.
3. If the host lacks systemd or `systemctl`, read `references/sbc-service-scripts.md` before configuring sing-box persistence.
4. Execute one phase at a time and verify each phase before continuing.
5. Run `scripts/check-dev-machine.sh` after setup or repair work. The script is read-only and should not modify the machine.

## Rules

- Do not write tokens, PATs, SSH keys, private subscriptions, node credentials, or API keys into docs or scripts.
- Do not use `systemctl` as the primary persistence mechanism on DSW/tini hosts.
- Keep sing-box in `mixed` mode unless the user explicitly asks for TUN and confirms the host supports it.
- Keep Git proxy, shell proxy variables, and install commands aligned to the user's active proxy endpoint.
- Prefer official installers or official release artifacts. If a mirror fails with 403 or stale packages, override it explicitly rather than debugging the wrong layer.
- Keep `/root/AGENTS.md` for agents and `/root/README.md` for users; do not mix operational rules with user-facing walkthroughs.

## Resources

- `references/bootstrap-phases.md`: staged setup plan with commands, validation points, and known DSW caveats.
- `references/sbc-service-scripts.md`: reference model for `sbc-start`, `sbc-stop`, and `sbc-status` on machines without systemd.
- `scripts/check-dev-machine.sh`: read-only validation script for core commands, versions, paths, and proxy hints.

## Completion Criteria

The machine is ready when the user can run `sbc version`, use the local proxy, run Codex/Claude, use Node 24 through nvm, use uv Python 3.12, and read `/root/AGENTS.md` plus `/root/README.md` for handoff details.
