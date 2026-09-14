---
name: disk-cleanup
description: Audit disk usage, rank findings by how long they have gone unused, and produce a risk-tiered deletion plan the human executes. Use when a user asks to clean up disk space, find large or long-unused files and directories, triage a full or nearly-full drive, reclaim space from caches, build artifacts, container images, system snapshots, or leftover data from uninstalled applications, or asks for a deletion checklist, deletion commands, or a repeatable cleanup strategy.
---

# Disk Cleanup

## Outcome

One ranked, risk-tiered deletion plan covering the **whole filesystem**, in which every line states
the path, its size, its last-modified date, and why it is safe. The human runs the deletions.

This skill never deletes anything. Its deliverable is a list plus evidence.

## The Loop

Everything in this skill exists to run one cycle, repeatably:

```
  measure          rank             classify          report           human
 ┌────────┐   ┌────────────┐   ┌─────────────┐   ┌────────────┐   ┌────────┐
 │ scan   │ → │ by size,   │ → │ into risk   │ → │ tiered     │ → │ picks  │
 │ wide   │   │ by age     │   │ tiers T0-T3 │   │ plan with  │   │ what   │
 │        │   │            │   │             │   │ evidence   │   │ goes   │
 └────────┘   └────────────┘   └─────────────┘   └────────────┘   └────────┘
                                                                      │
                    agent re-scans and reports the delta  ←───────────┘
```

The agent owns measure, rank, classify, and report. The **human owns the decision** — which paths
are worth their space is a judgment about the human's work, not a property of the filesystem. Never
collapse the last step into the first four; a plan that arrives already executed has removed the
only decision that was the human's to make.

`scripts/disk-triage.sh` is the measure step, and `references/scan-playbook.md` is the same
measurement spelled out as individual commands for when a narrower probe is needed. Everything else
here is how to turn those numbers into something a human can decide against.

## Mental Model

**Recency is the primary ranking signal, size is the secondary one.** "Big" alone is not a reason to
delete — a 17 GB container image for a project under active development stays. "Untouched for a long
time" is what makes a large item a candidate. Rank by age bucket first, then by size within the bucket.

**Deletion authority is tiered, and the tier decides who acts.**

| Tier | Meaning | Who acts |
|---|---|---|
| **T0** | Cache, trash, temp. Regenerated automatically. | Agent may propose a single consolidated command. |
| **T1** | Installed packages, superseded versions, redundant copies, rebuildable artifacts. | Agent proposes; human runs. |
| **T2** | Could be the only copy of something. Large or ambiguous. | Agent asks per item, with evidence. |
| **T3** | Credentials, databases, browser profiles, session history. | **Never proposed.** See `references/classification.md`. |

**A directory name is not evidence of ownership.** Before declaring anything an orphan, confirm the
owning application is actually gone using independent signals — `command -v`, `.desktop` entries,
`dpkg -l`, `flatpak list`, `snap list`. An app being absent from `~/.config` proves nothing, and a
data directory present without a binary proves nothing either. Check, then claim.

**The home directory is not the filesystem.** On this class of machine the largest consumers are
routinely outside `$HOME`. Always scan `/var/lib/docker`, `/timeshift`, `/snap`, `/opt`, `/usr`, and
`/var` before reporting a total — a home-only audit missed 183 GB on the machine this skill was
derived from.

## Workflow

Run `scripts/disk-triage.sh` first. It is read-only and produces the raw measurements; the phases
below are how to turn those into a plan.

### 1. Measure the whole filesystem

Top-level `du` across every mount, then descend only into what is large. Do not descend everywhere —
measure wide, drill narrow. See `references/scan-playbook.md` for the command set.

Record the starting `df` output. Every later claim of "freed N GB" is measured against it.

### 2. Age everything

**Use `mtime`. Never use `atime`.**

`atime` is unusable on ext4 with the default `relatime` mount option: it updates only when the
existing atime is older than mtime or more than 24h stale, and **any scan you run refreshes it**.
A `find -atime` run will report every directory as touched today, including ones last written in
2024. This is not a subtle bias — it inverts the ranking. Use `find ! -newermt <date>` and
`stat -c '%y'`.

Bucket findings as: >2 years, 1–2 years, 6–12 months, <6 months.

### 3. Classify against the decision profile

Apply the tier table above, then apply this machine's owner's confirmed preferences in
`references/classification.md`. Those preferences are not defaults to be re-litigated each run —
they were established by explicit human choice.

### 4. Verify every orphan claim

For each candidate, collect an independent signal before listing it. Then **exclude** anything that
turns out to still be in use, and say so explicitly in the report. A cleanup list that includes a
live application's data directory costs the human more than the space it frees.

### 5. Emit the plan

Structure: a tier summary table, then per-tier detail with exact literal paths, then the commands.

Lead with the single largest item. Group commands so the human can run one tier at a time and stop
between tiers. Print the `df` comparison command so the result is checkable.

When a measurement is counter-intuitive — hardlink double-counting, compressed/uncompressed pairs,
shared layers — say so in the report. Otherwise the human will act on a number that is ten times
too large.

## Hard Boundaries

Never propose deletion of, and never include in a command list:

- Browser profiles — `~/.config/{google-chrome,chromium,BraveSoftware,*/Default}` hold bookmarks,
  saved passwords, and sessions. The **cache** lives in `~/.cache/` and is the only safe target.
- Chat databases — `~/Documents/xwechat_files/*/db_storage`, `~/.config/QQ/*/nt_db`.
- Received files — `~/Documents/xwechat_files/*/msg`.
- Credentials — `~/.ssh`, `~/.gnupg`, `~/.git-credentials`, `~/.netrc`, `~/.aws`.
- Agent session history — `~/.claude/projects`, `~/.codex/sessions`.
- Reference libraries — `~/Zotero`, `~/Documents/**` outside named caches.

Full list with reasoning: `references/classification.md`.

## Verify

Before presenting a plan:

1. Every path in the plan was measured, not inferred, in this session.
2. Every path labelled orphan has a recorded absent-owner signal.
3. Every "never delete" category has been checked against the candidate list.
4. The `df` before/after command is included.
5. No compressed/uncompressed or hardlinked pair is counted twice.

## References

- `references/scan-playbook.md` — measurement commands, including the system-level sweep.
- `references/classification.md` — tier definitions, the decision profile, the never-delete list,
  and the catalog of confirmed reclaim targets for this machine.
