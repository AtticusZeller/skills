# Communicating With a Worker

## Channels

There is no live channel into a running worker. It runs one round to completion, and all
communication happens between rounds.

| Direction | Channel | Stored at |
|---|---|---|
| Orchestrator → worker, first round | Brief file passed on stdin | `rounds/001.brief.md` |
| Orchestrator → worker, every round | Fixed contract in the appended system prompt, plus `AGENTS.md` when the worker would not discover it | `system-prompt.md` |
| Inherited environment → worker | `CLAUDE.md`, plugins, skills, MCP servers, and hooks, unless the worker was created with `--bare` | user and project settings |
| Orchestrator → worker, later rounds | `resume --message` or `--brief`, delivered into the same session | `rounds/NNN.brief.md` |
| Worker → orchestrator | Final report text plus result JSON: status, turns, denials, session id | `rounds/NNN.result.json` |
| Worker → orchestrator | Files it created or changed in `--cwd` | the working tree |
| Worker → orchestrator | Diagnostics when the round fails | `rounds/NNN.stderr.log` |
| Worker ↔ user | None. The orchestrator relays in both directions | — |

When the worker is blocked or unsure, it ends the round with a `Questions` section instead of
guessing. The orchestrator answers from the conversation or asks the user, then resumes with the
answer. That is the whole question loop.

## Brief template

Write a new brief for each task. Keep it self-contained: the worker has not seen the conversation.

```markdown
# Task: <one line>

## Goal
<What must be true when the worker finishes, as observable outcomes.>

## Context
<Facts the worker cannot discover itself: decisions already made, why, and which files to read first.>

## Inputs
- <exact paths, exact target structure, exact names>

## Constraints
- Do not modify: <paths>
- Out of scope: <things to leave alone>
- <repository-specific rules not covered by AGENTS.md>

## Deliverable
<Files to create or change, or the question to answer, and the expected length of the answer.>

## Done when
- <check the orchestrator will run, such as `diff -rq a b` or a heading list>
```

Name the checks you will run in `Done when`. A worker that knows the acceptance test aims at it.

## Report contract

`assets/worker-contract.md` fixes the report sections: `Result`, `Changed files`, `Checks run`,
`Not done`, and `Questions`. Do not restate the format in the brief. If a report is missing sections,
resume and ask for them rather than filling the gaps with guesses.

## Verification checklist

Before relaying anything:

1. **Status and denials.** A round can finish `ok` after many denials. Each denial is a place where
   the worker may have substituted a different approach or silently skipped a step.
2. **Changed files.** Compare `git status --short` or a directory listing with the report's
   `Changed files`. Look for writes it did not mention and for claimed files that do not exist.
3. **Claimed checks.** For every entry in `Checks run`, confirm the command was permitted, or rerun
   it. Treat a check whose tool was denied as not run, whatever the report says.
4. **Content.** Inspect the actual output, not a summary: headings, byte-level diffs, a rendered
   build if one is cheap.
5. **Scope.** Confirm it touched nothing outside the brief's constraints.

## Relaying to the user

Separate the three categories plainly:

- **Verified**: what you checked yourself, and how.
- **Worker-reported, unverified**: anything you could not check.
- **Open**: the worker's `Questions` and `Not done` items that need the user.

Give the worker name, so the user can say "continue `report-v3-scaffold`" later.
