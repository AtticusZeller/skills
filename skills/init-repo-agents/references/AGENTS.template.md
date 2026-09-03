# {{PROJECT_NAME}} · Agent Rules

> {{ONE_LINE_PURPOSE}}

**Primary toolchain:** {{PRIMARY_TOOLCHAIN}}

Human sets the boundaries; agent implements and verifies within them.
Ask for decisions, not for work the agent can perform.

## 1. Ownership

Human owns intent, scope, architecture, interfaces, task decomposition, and acceptance criteria.

Agent owns implementation, local technical decisions, testing, debugging, lint/typecheck, and evidence
collection.

The agent may propose options or task breakdowns. Human approval determines the plan. Do not change
human-owned decisions, expand scope, or weaken acceptance criteria without explicit approval.

## 2. Before Implementation

Read relevant code, project documentation, and applicable repository instructions first. Establish
current behavior and constraints from evidence. For continued work, read the applicable plan and log,
then compare their claims with the current code and working tree.

Read-only requests remain read-only. Inspection and non-destructive diagnostics may proceed before
implementation approval; do not modify source, configuration, or dependencies during that phase.

Before implementation, make the task explicit: goal, scope and non-goals, affected components,
interfaces, expected behavior, constraints, and observable acceptance criteria. Every task defines:

```text
Task = Change + Observable Evidence

Change: what will be implemented or changed
Verification: how correctness will be checked
Done: the observable result that counts as accepted
```

Investigate repository facts yourself. Ask focused questions only for unresolved human-owned decisions
or context that available evidence cannot establish. Surface contradictions between the request, plan,
documentation, and code. Do not infer intended behavior solely from the current implementation.

Present the refined task or plan for explicit confirmation. Silence, lack of objection, and agent
confidence are not confirmation. An explicit instruction to execute an agreed plan counts as
confirmation.

## 3. Implementation and Verification

After confirmation, implement the approved plan autonomously. Existing approval remains valid inside
its stated scope; do not request it again for routine implementation, testing, debugging, or repairs.

Follow `karpathy-guidelines`: make the smallest surgical change, avoid speculative design, state
assumptions explicitly, and keep each changed line traceable to the approved task.

Do not add unrequested features, abstractions, dependencies, refactors, or cleanup.

Assumptions may resolve local implementation details only. Scope, architecture, interfaces, task
decomposition, expected behavior, and acceptance criteria require human confirmation.

For each task, run the loop:

```text
change -> test -> inspect failure -> fix -> retest
```

Run every relevant check available in the current environment.
Do not ask the user to run checks the agent can run.
Diagnose failures from logs, tracebacks, and reproducible observations; each retry must test a concrete
hypothesis. Never bypass a failing check or weaken an assertion merely to obtain a pass. Rerun checks
invalidated by a later fix.

Inspect the final diff for unintended changes and preserve pre-existing or unrelated work. Do not commit
or push unless the user asks. When committing is requested, stage only the verified task and inspect the
staged diff first.

## 4. Evidence and Stop Conditions

A task is complete only when observable evidence satisfies every acceptance criterion. Report changed
behavior, checks run, acceptance status, and remaining limitations. Commands supplied to the user are
not evidence that they passed.

If verification genuinely requires unavailable hardware, data, credentials, or an external environment,
finish every agent-accessible check first. Give the user prerequisites, copyable commands, unambiguous
pass criteria, and the evidence to return on failure. Keep the task pending until results are observed.

Stop the affected work and return the smallest unresolved decision when:

- a human-owned decision or acceptance criterion must change;
- intent remains ambiguous after relevant investigation;
- the next action is destructive or irreversible without explicit authorization;
- debugging repeats without new evidence or meaningful progress;
- required hardware, data, credentials, or environment access blocks verification.

When stopping, report the blocker, evidence, attempts, current state, and the smallest decision or input
needed to continue. Distinguish observed facts from hypotheses and never present an unverified workaround
as a confirmed fix.

## 5. Skills

Use an available Skill whenever the task matches its description. Read its `SKILL.md` before acting. A
Skill provides execution guidance; it does not expand scope or authorization.

- `karpathy-guidelines` — implementation, code review, and refactoring discipline.
- `context7-cli` / `find-docs` — current library, framework, SDK, API, CLI, and cloud documentation.
- `gh-cli` — GitHub URLs, issues, pull requests, and authenticated repository operations.
- `modern-python` — Python project initialization and tooling migration.
- `skill-creator` — creating or materially updating a reusable Skill.
- `neat-freak` — explicitly requested knowledge, documentation, or workspace closeout.
- `git-commit` — only when the user asks to commit.
- `explain-diff-html` — only when the user asks for a rich diff explanation.

Add repository-local Skills here when their triggers are part of normal project work. Never turn Skill
names into an automatic workflow chain.

## 6. Project Boundaries

Stay inside the assigned repository, branch, and workspace unless the user explicitly changes the
assignment. Do not create or switch worktrees, schedule parallel work, or delegate to another agent
without authorization.

Use `{{ENTRY_POINT}}` as the unified project entry point. Put stable, repeated operations behind this
interface instead of making users or agents reconstruct long commands. Keep orchestration in the entry
point and implementation in the appropriate source modules.

When complex configuration is part of the project, prefer complete, reviewable configuration files over
long command lines. Temporary overrides must not obscure the reproducible baseline.

Before editing anything under `docs/`, read `docs/AGENTS.md`. Documentation is human-facing project
context, not a copy of source code, command output, or Git history.

## 7. Code and Language

- Follow the repository's established formatter, linter, type checker, tests, and naming conventions.
- Use Google-style docstrings in Python projects unless the repository declares another standard.
- Comments explain why a coherent block exists, not what each statement does.
- Write `AGENTS.md`, `CLAUDE.md`, Skill instructions, code comments, and docstrings in English.
- Write user-facing documentation in the repository's chosen documentation language.
