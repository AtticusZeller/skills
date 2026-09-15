---
name: delegate-worker
description: Delegate a bounded task to a Claude Code worker running on a third-party provider configured in cc-switch (for example DeepSeek), keep that worker's session for follow-ups, and verify its report before relaying it. Use when the user asks to have DeepSeek or another cc-switch provider do the work, wants a cheaper external worker to explore, draft, or perform mechanical edits, asks to continue, correct, or fork a previously delegated worker, or asks whether to reuse an existing worker. Do not use for native same-provider subagents, work that needs claude.ai connectors or MCP servers, or tasks the user wants done directly.
---

# Delegate Worker

## Roles

A native subagent always inherits the calling session's provider, so it cannot run on DeepSeek while
the caller runs on Claude. This skill instead launches a **separate Claude Code process** through
`cc-switch start claude <provider>` and treats it as a worker.

| Role | Owns |
|---|---|
| Orchestrator (the calling agent) | Choosing new/resume/fork, writing the brief, choosing permissions, verifying the report, talking to the user |
| Worker (the cc-switch process) | Executing the brief inside its permissions and returning the fixed report format |
| Human | Scope, commits, pushes, switching repository state, accepting results |

The worker's report is **evidence to check, not a result to relay**. In practice workers have
claimed verifications that their permissions had blocked. Verify before you report.

## Workflow

`scripts/delegate-worker.sh` is the only supported driver. It stores each worker under
`${XDG_STATE_HOME:-~/.local/state}/delegate-worker/<name>/`.

1. **Look for an existing worker.**
   `delegate-worker.sh list`. Decide new, resume, or fork with `references/decision-rules.md`.
2. **Write the brief to a file** in the scratchpad, following `references/communication.md`.
   A new worker knows nothing about the conversation.
3. **Run it.**

   ```bash
   S=<skill-dir>/scripts/delegate-worker.sh
   $S new    <name> --provider deepseek --cwd <repo> --profile readonly --brief brief.md
   $S resume <name> --message "Answer to Q1: use 90_references.md. Continue."
   $S fork   <name> <new-name> --brief alternative.md
   ```

   Tasks that may exceed about 8 minutes go through the Bash tool with `run_in_background`. Do not
   poll, because the exit notification arrives on its own. Then run `delegate-worker.sh show <name>`.
4. **Read the report**: status, turns, permission denials, then the result text.
5. **Verify mechanically**: `git status`, `diff`/`cmp`, and rerun the checks it claims. See the
   checklist in `references/communication.md`.
6. **Close the loop.** Answer its `Questions`, or correct a mistake, by resuming. Start over only
   when the decision rules say so.
7. **Report to the user.** Separate what you verified from what the worker merely claimed, and
   name the worker so the user can ask for a follow-up later.

## Permission Profiles

Choose a profile at `new`. It stays fixed for the worker's life; `--allow RULE` adds rules that
persist across later rounds.

| Profile | Allows | Denies |
|---|---|---|
| `readonly` (default) | Read, Glob, Grep, Skill, ToolSearch, `ls`, `wc`, `rg`, `git status/log/diff/show` | Edit, Write, NotebookEdit |
| `edit` | readonly plus Edit, Write, `mkdir`, `cp`, `mv`, `touch`, `diff`, `cmp` | writes under `~/.claude` and `~/.codex`, `rm`, `git add/commit/push/reset/checkout/restore` |

Tell the worker to run one command per Bash call. Rules match the whole command, so
`mkdir a && cp b c` is denied even when `mkdir` and `cp` are each allowed. A denied worker retries in
new shapes and burns turns.

For `edit` work in a Git repository, prefer a dedicated worktree or branch as `--cwd`, so the diff is
reviewable and easy to discard.

## Inheritance and Isolation

By default a worker is an ordinary Claude Code session. It inherits what makes it behave like the
calling session: global and project `CLAUDE.md`, plugins, skills, MCP servers, hooks, and output
style. Every profile allows `Skill` and `ToolSearch`, because print mode denies any tool that is not
allowed. MCP tools still need an explicit `--allow mcp__<server>__<tool>`. claude.ai connectors are
unavailable, because cc-switch authenticates with an API key.

Claude Code discovers `CLAUDE.md` but never `AGENTS.md`. The script always appends
`assets/worker-contract.md` to the worker's system prompt. When `--cwd` has an `AGENTS.md` but no
`CLAUDE.md`, it appends that file as well. The system prompt is recorded on the first round and is
not rebuilt on resume.

Inherited hooks and auto-memory run inside the worker as well. The `readonly` profile denies every
file write, and `edit` denies writes under `~/.claude` and `~/.codex`, so no profile lets a worker
write agent memory or settings.

Pass `--bare` at `new` for a clean-room worker: no hooks, plugins, MCP, auto-memory, or `CLAUDE.md`
discovery. The script then inlines the first of `AGENTS.md` or `CLAUDE.md` it finds. Use this for a
second opinion that should not be shaped by the user's setup, or when an inherited hook misbehaves.

## Hard Boundaries

- Never put secrets, tokens, or private files such as `99_Private/` into a brief.
- Never let a worker commit, push, or rewrite Git history. The orchestrator does that after
  verifying, and only when the user asks.
- Never relay a worker's claim of a check it ran without rerunning or inspecting that check.
- Do not delegate work that depends on claude.ai connectors or on this conversation's unstated
  context.
- The `total_cost_usd` in results is Claude Code's Anthropic-priced estimate. The provider bills
  separately.

## References

- `references/decision-rules.md`: new vs resume vs fork, naming, and when to retire a worker.
- `references/communication.md`: channels, brief template, report contract, question loop, and
  verification checklist.
- `assets/worker-contract.md`: the fixed worker-side contract. The script deploys it; do not
  paraphrase it into a brief.
