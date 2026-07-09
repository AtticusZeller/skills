---
name: init-repo-agents
description: Initialize repository-level agent collaboration scaffolding for a new or existing project. Use this whenever the user wants to set up AGENTS.md / CLAUDE.md baseline rules, bootstrap a repo's agent config, define the session lifecycle for a codebase, create the in-repo docs/ memory (plan.md / log.md / bug.md) so context stays portable across machines and CLIs, or seed a [[docs/<module>.md]] code-doc index. Trigger on phrases like "初始化这个仓库", "给项目配 AGENTS.md", "init repo agents", "bootstrap this project for agents", or "set up the project memory/docs". Prefer this skill over ad-hoc file creation whenever a project lacks agent baseline rules or an in-repo memory layer.
---

# Init Repo Agents

## Overview

Use this skill to give any repository a portable, self-contained agent baseline in a single pass. The output lives **inside the repo** (`AGENTS.md`, mirrored `CLAUDE.md`, and `docs/`) rather than in a CLI-specific global memory, so the same context follows the project across machines and across agents (Codex, Claude Code, etc.).

The skill does four things, in order: confirm the user's global skills are present, write the agent baseline rules (including the session lifecycle), scaffold the in-repo memory files, and seed a lazy code-doc index. It deliberately does **not** deep-read the codebase to auto-generate module docs — those are filled incrementally as work happens, to avoid re-reading a large repo up front.

Treat running this skill as a setup task: it is idempotent and must never clobber content the user already wrote.

## Workflow

Execute these steps in order. Confirm with the user before overwriting anything that already exists.

1. **Idempotent detection.** Check whether `AGENTS.md`, `CLAUDE.md`, and `docs/` already exist. If they do, switch to incremental top-up mode: only add missing sections/files, and never overwrite existing user content. Report what already exists before proceeding.

2. **Verify global skills.** Confirm the user's personal global skills are installed:

   ```bash
   npx skills add AtticusZeller/skills --list --full-depth
   ```

   The baseline rules reference these external global skills — confirm the ones this project will lean on are present: `neat-freak`, `karpathy-guidelines`, `modern-python` (for Python projects), `find-docs` / `context7-cli` (`ctx7`), `git-commit`, `gh-cli`. If any are missing, point the user at:

   ```bash
   bash scripts/install-global-skills.sh
   ```

   Note: `grill` is not a globally installed skill, so its workflow is embedded directly in `references/AGENTS.template.md` and needs no install.

3. **Lightweight alignment (grill).** Ask the user, one question at a time, only for facts you cannot get by reading the repo or its docs:
   - Project name and one-line purpose.
   - Primary language and toolchain (e.g. Python + uv/ruff/ty, Node + pnpm).
   - The unified entry point (prefer `dev.sh`) and whether experiments are driven by YAML configs (e.g. `experiments/<name>.yaml`).
   - The handful of top-level modules that matter most.

   Give a recommended answer + one-line why for each question. Skip questions the code already answers.

4. **Write AGENTS.md (+ mirror CLAUDE.md).** Read `references/AGENTS.template.md`, fill the `{{PLACEHOLDER}}` fields with project-specific facts (overview, toolchain, entry point, module index), and write it to the repo root `AGENTS.md`. Then mirror the identical content to `CLAUDE.md` so Claude Code and Codex both read the same baseline. Keep the two files byte-identical.

5. **Scaffold docs/ memory.** Following `references/docs-scaffold.md`, create `docs/plan.md`, `docs/log.md`, and `docs/bug.md` if they are absent, each with its header and append convention. These are the portable, in-repo memory layer — do not put this content in a CLI global memory.

6. **Seed the code-doc index.** Do a shallow directory scan of the top-level source tree (e.g. `src/<pkg>/*/`) — structure only, no deep code reading. Populate the "代码文档索引" section of `AGENTS.md` with `[[docs/<module>.md]]` entries pointing at docs to be written later, plus the convention line explaining that module docs are filled incrementally to avoid re-reading code. Do not generate module doc bodies now.

7. **Wrap up.** Summarize which files were created vs. topped-up, and give next-step pointers: run `grill` before large changes, `neat-freak` at milestones, add a `docs/<module>.md` the first time a module is explored in depth, and — per section 6 of the template — adopt the `dev.sh` + YAML-driven experiments pattern (wrap common dev commands into `dev.sh` subcommands; keep complex experiment params in `experiments/<name>.yaml` with `dev.sh` options overriding them).

## Rules

- Idempotent and non-destructive: never overwrite existing `AGENTS.md`, `CLAUDE.md`, or `docs/` content. Top up only.
- Keep `AGENTS.md` and `CLAUDE.md` byte-identical mirrors.
- Do not deep-read the codebase during init. Seed the index from a shallow structural scan only.
- Keep memory in-repo (`docs/`), never in a CLI-specific global memory, so it is portable.
- Language convention for generated files: user-facing docs (`AGENTS.md`, `docs/`, `cmd.md`) in Chinese; code comments and agent-internal notes in English.
- The session lifecycle in `AGENTS.template.md` is the top-level behavioral constraint — preserve it verbatim when filling the template.

## Resources

- `references/AGENTS.template.md`: the baseline `AGENTS.md` template — session lifecycle (section 0) + the full generalized agent rules, with embedded grill workflow and named references to global skills. Fill placeholders; do not compress the rules.
- `references/docs-scaffold.md`: templates and conventions for `docs/plan.md`, `docs/log.md`, `docs/bug.md`, and the `[[docs/<module>.md]]` index.

## Completion Criteria

The repo is initialized when: `AGENTS.md` exists with the session lifecycle and full baseline rules, `CLAUDE.md` mirrors it exactly, `docs/{plan,log,bug}.md` exist with correct headers, `AGENTS.md` carries a seeded `[[docs/<module>.md]]` index, and nothing the user previously wrote was overwritten.
