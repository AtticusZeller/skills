---
name: remote-machines
description: Registry and operating rules for remote machines reached over SSH (training servers, inference servers, robot clients, lab and personal hosts). Use whenever a task involves SSH, a remote machine or server, running/monitoring jobs remotely, syncing code to a remote host, checking remote GPUs/disks, or names any alias registered under ~/.config/remote-machines/machines/ or defined in ~/.ssh/config.
---

# Remote Machines

Each remote machine is an object: static facts live in a YAML registry, dynamic state is probed
on demand, and frequent or risky operations go through the scripts here. Nothing is installed on
the remote side; everything runs locally over SSH.

- Registry: `~/.config/remote-machines/machines/<alias>.yaml` (override with
  `REMOTE_MACHINES_DIR`). File name = `Host` alias in `~/.ssh/config`. Shared values live in
  `_defaults.yaml` and `_<group>.yaml` files pulled in with `extends`. Schema:
  [references/schema.md](references/schema.md).
- `~/.ssh/config` stays the source of truth for addresses, users, ports, keys and jumps. Never
  copy those into YAML. Connection reuse and hang recovery:
  [references/ssh-config.md](references/ssh-config.md).
- Scripts live in `scripts/` next to this file and need only `uv` locally (PyYAML is resolved by
  `uv run --script`).

## Workflow

1. **Read the registry first.** When a task touches a machine, read its YAML (`extends` and
   `_defaults.yaml` included) before opening any SSH session. Do not explore the host to rediscover
   what the registry already says.
2. **Probe for live state.** `scripts/probe <alias> [gpu|disk|jobs|git|load]` gives free GPUs,
   disk use of registered paths, tmux jobs (yours vs others), repo status, and load in one SSH
   round trip. It is read-only.
3. **Operate through the scripts.** Prefer `rx`, `rjob`, and `rgit` over hand-built SSH
   strings; use bare `ssh -T -o BatchMode=yes -o ConnectTimeout=15 <alias> '<cmd>'` for the
   long tail. Search remote code with `ssh <alias> rg ...` when the registry says `rg` exists.
4. **Keep the registry current.** When you find new static facts (a new env, path, tool, rule),
   edit that machine's YAML (or the shared `_<group>.yaml`) and tell the user what changed.
   Never write dynamic state (GPU memory, disk free, running jobs, git status) or any secret.
5. **`risk: high` machines** (robot clients): ask the user before any state-changing action —
   motion commands, starting or restarting services, config edits, anything in `confirm_ops`.
   Read-only inspection needs no confirmation.
6. **Shared machines** (`shared: true`): install nothing, change no global config, never touch
   other people's processes, sessions, or files, and follow `shared_rules`.

## Scripts

| Script | Use |
| --- | --- |
| `rx <alias> [--repo R [--task T]] [--env E]... -- <cmd>` | Foreground command. `--repo` cds into R; with `--task T` into your own copy `<work_root>/T/R`. `--env` repeats and activates in order. |
| `rjob start <alias> <name> [--repo R [--task T]] [--env E]... -- <cmd>` | Background job: tmux session `<name>` with `remain-on-exit`, output tee'd to `<dirs.logs>/<name>.log`, tagged `@owner`. Falls back to `nohup setsid` + pid file without tmux. |
| `rjob logs <alias> <name> [-n N] [--follow]` / `rjob ls <alias> [--all]` / `rjob stop <alias> <name> [--rm-log]` | Inspect and clean up. `ls` and `stop` act on your own (`@owner`) sessions only. |
| `rgit clone <alias> --repo R --task T` | Own work copy via `git clone --shared` (borrows the shared repo's objects read-only, so it is instant even for huge histories); origin is repointed to the shared repo's upstream URL. |
| `rgit push <alias> --repo R [--task T] [--branch B] [--checkout] [--bundle]` | Ship local commits (not uncommitted edits) to `refs/remotes/laptop/B` in your copy; `--checkout` fast-forwards B there. |
| `probe <alias> [sections...]` | Live state, read-only. |
| `bootstrap [alias...] [--force] [--dry-run]` | Draft registry YAML from ssh config plus one read-only probe; never overwrites. |

Every script takes `--dry-run` (for `rjob`/`rgit`, before the subcommand) to print the exact SSH
command. Job and task names are plain names (letters, digits, `.`, `_`, `-`); the job name is the
tmux session name, so use the task name.

## Code on shared machines

Shared checkouts (`repos.<name>.shared: true`) are read-only for you: run from them, never edit,
check out, pull, or push into them. To test your own change:

1. Commit locally (no need to push to GitHub yet).
2. `rgit clone <alias> --repo R --task T` once, to get your own copy.
3. `rgit push <alias> --repo R --task T --checkout`, then run with `rx`/`rjob ... --repo R --task T`.
4. Push to GitHub only after the change has been verified on the machine.

If `--checkout` refuses because you rewrote local history, the old commits are still on the
remote branch; ask the user before resetting that branch to `laptop/B`. Edit non-git files
locally and `rsync` them; avoid heredoc/`sed` rewrites of large remote files.

## Remote hygiene

- `history_off: true` machines get `unset HISTFILE; set +o history` prefixed automatically; add it
  yourself in any interactive or tmux shell you open there.
- Do not leave probe scripts, command transcripts, or ad-hoc logs on remote machines. Job logs
  under `dirs.logs` are task output; remove them with `rjob stop --rm-log` when they are not
  needed. This prevents agent-created records only; never touch SSH or platform audit logs.
- Unreachable host: check `network`/`reach` in its YAML (Wi-Fi, campus network, jump host) before
  retrying, and do not retry more than once.
