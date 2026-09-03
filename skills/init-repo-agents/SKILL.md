---
name: init-repo-agents
description: Initialize or refresh repository-level AGENTS.md, CLAUDE.md, documentation contracts, and explicit Skill routing around a human-owned task model. Use when a user asks to initialize, create, audit, or update repository agent rules or portable project context.
---

# Init Repo Agents

## Outcome

Give a repository one current, portable collaboration contract:

- `AGENTS.md` is the authoritative agent-facing rule file;
- `CLAUDE.md` imports `AGENTS.md` instead of copying it;
- `docs/AGENTS.md` defines concise human-facing plan, log, and overview documents;
- repository rules name the commonly used Skills and their actual triggers.

The baseline is about how confirmed work is performed. It does not classify sessions or decide what the
human should build.

## Mental Model

Human owns intent, scope, architecture, interfaces, task decomposition, and acceptance criteria. Agent
owns implementation, local technical decisions, debugging, testing, and evidence collection.

Every implementation task is `Task = Change + Observable Evidence`. Before implementation, make the
Change, Verification, and Done conditions explicit and obtain confirmation for unresolved human-owned
decisions. Once confirmed, continue autonomously inside that scope.

Two implementation rules are non-negotiable:

- Do not add unrequested features, abstractions, dependencies, refactors, or cleanup.
- Do not ask the user to run checks the agent can run.

## Workflow

1. **Inspect the repository.** Read the active rule chain, `README.md`, existing docs contracts, primary
   entry point, toolchain metadata, and available repository-local Skills. Treat existing content as
   evidence, not as permission to overwrite it.
2. **Resolve project facts.** Determine project name, one-line purpose, toolchain, and unified entry point
   from the repository. Ask only when a human-owned choice remains unresolved.
3. **Define the change.** State Change, Verification, and Done. For an existing rule set, explain which
   rules will be retained, removed, or added. Get explicit confirmation before changing governance.
4. **Route Skills explicitly.** Record only Skills that are available and regularly relevant to the
   repository. Give each one a concrete trigger. A Skill supplies execution guidance; it does not expand
   task scope or authorization.
5. **Initialize a new repository.** Preview the deterministic initializer, inspect its output, then run it:

   ```bash
   bash scripts/init-repo-agents.sh \
     --target "$REPO_ROOT" \
     --project-name "$PROJECT_NAME" \
     --purpose "$ONE_LINE_PURPOSE" \
     --toolchain "$PRIMARY_TOOLCHAIN" \
     --entry-point "$ENTRY_POINT" \
     --dry-run
   ```

   Repeat without `--dry-run`, then run `scripts/check-repo-agents.sh --target "$REPO_ROOT"`.
6. **Update an existing repository manually and surgically.** Do not run the initializer over custom
   `AGENTS.md` or `CLAUDE.md`. Patch the authoritative rule file according to the confirmed change,
   preserve repository-specific constraints, keep `CLAUDE.md` as a short import when supported, and
   update docs only when their contract is affected.
7. **Verify.** Run the checker for generated scaffolding, repository-native lint/tests, link checks, and
   searches for removed workflow terms or dead paths. Inspect the final diff and report limitations.

## Generated Baseline

`scripts/init-repo-agents.sh` is create-only and idempotent. It refuses to replace custom rule files. It
creates:

- `AGENTS.md` from `references/AGENTS.template.md`;
- `CLAUDE.md` containing only `@AGENTS.md`;
- `docs/AGENTS.md`;
- `docs/workspace/plan.md`, `log.md`, and `overview.md`.

It does not create a root command notebook, bug journal, understanding-debt ledger, workflow classifier,
or managed block. Add project-specific documentation areas only when the repository actually needs them.

## Common Skill Routing

When installed and applicable, prefer these standard routes in generated or updated rules:

- `karpathy-guidelines` for implementation, review, and refactoring discipline;
- `context7-cli` or `find-docs` for current library, framework, SDK, API, CLI, or cloud documentation;
- `gh-cli` for GitHub URLs, issues, pull requests, and authenticated repository operations;
- `modern-python` for Python project initialization or tooling migration;
- `skill-creator` for creating or materially updating a reusable Skill;
- `neat-freak` for an explicitly requested knowledge or workspace closeout;
- `git-commit` only when the user asks to commit;
- `explain-diff-html` only when the user asks for a rich diff explanation.

Also list repository-local Skills whose task triggers are part of normal project work. Do not chain any of
these Skills into an automatic lifecycle.

## Constraints

- Never run the legacy managed-block updater or restore its lifecycle.
- Never overwrite custom `AGENTS.md`, `CLAUDE.md`, or existing docs assets.
- Keep the template generic; repository-specific algorithm, deployment, hardware, or experiment rules
  belong in that repository's confirmed additions.
- Keep agent-facing rules and Skill instructions in English. Keep generated human-facing docs in the
  repository's chosen documentation language; the bundled starter uses concise Chinese.
- Do not install, commit, push, delete, or publish anything unless the user's request authorizes it.

## Resources

- `references/AGENTS.template.md` — fixed baseline for a new repository.
- `references/docs-scaffold.md` — plan/log/overview contracts and routing guidance.
- `scripts/init-repo-agents.sh` — create-only deterministic initializer.
- `scripts/check-repo-agents.sh` — semantic scaffold checker.
- `scripts/test-init-repo-agents.sh` — fidelity, idempotency, refusal, and checker regression tests.
- `assets/docs/` — exact create-if-absent documentation bodies.

## Completion Criteria

The task is complete when the intended repository has one authoritative rule source, Skill routes match
the available workflows, docs have no competing current answer, all relevant checks pass, and every
unverified or intentionally untouched state is reported explicitly.
