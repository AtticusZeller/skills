---
name: init-repo-agents
description: Initialize repository-level agent collaboration scaffolding for a new or existing project. Use this whenever the user wants to set up AGENTS.md / CLAUDE.md baseline rules, bootstrap a repo's agent config, define the session lifecycle and post-code verification gate for a codebase, create the in-repo docs/ memory (plan.md / log.md / bug.md) so context stays portable across machines and CLIs, create a cmd.md user-test handoff, or seed a docs/module-name.md code-doc index. Trigger on phrases like "初始化这个仓库", "给项目配 AGENTS.md", "init repo agents", "bootstrap this project for agents", or "set up the project memory/docs". Prefer this skill over ad-hoc file creation whenever a project lacks agent baseline rules or an in-repo memory layer.
---

# Init Repo Agents

## Overview

Use this skill to give any repository a portable, self-contained agent baseline in a single pass. The output lives **inside the repo** (`AGENTS.md`, mirrored `CLAUDE.md`, and `docs/`) rather than in a CLI-specific global memory, so the same context follows the project across machines and across agents (Codex, Claude Code, etc.).

The skill confirms the user's global skills, gathers the small set of project facts needed by the template, and then delegates all fixed file generation to `scripts/init-repo-agents.sh`. The script renders the complete baseline rules, scaffolds the in-repo memory files, creates `cmd.md`, and seeds a lazy code-doc index. It deliberately does **not** deep-read the codebase to auto-generate module docs — those are filled incrementally as work happens, to avoid re-reading a large repo up front.

Treat running this skill as a setup task: it is idempotent and must never clobber content the user already wrote.

## Workflow

Execute these steps in order. Resolve every bundled path relative to this `SKILL.md`, not relative to the target repository.

1. **Inspect without rewriting.** Identify the target repository root and check whether `AGENTS.md`, `CLAUDE.md`, `docs/`, and `cmd.md` exist. Do not manually merge or rewrite them. The initializer updates only its complete managed block and preserves each file's existing suffix independently; fixed docs assets are create-if-absent.

2. **Verify global skills.** Confirm the user's personal global skills are installed:

   ```bash
   npx skills add AtticusZeller/skills --list --full-depth
   ```

   The baseline rules reference these external global skills — confirm the ones this project will lean on are present: `neat-freak`, `karpathy-guidelines`, `modern-python` (for Python projects), `find-docs` / `context7-cli` (`ctx7`), `git-commit`, `gh-cli`. If any are missing, point the user at:

   ```bash
   bash scripts/install-global-skills.sh
   ```

   Note: `grill` is not a globally installed skill, so its workflow is embedded directly in `references/AGENTS.template.md` and needs no install.

3. **Lightweight alignment (grill).** Ask the user, one question at a time, only for arguments you cannot get by reading the repo or its docs:
   - Project name and one-line purpose.
   - Primary language and toolchain (e.g. Python + uv/ruff/ty, Node + pnpm).
   - The unified entry point (prefer `dev.sh`) and whether experiments are driven by YAML configs (e.g. `experiments/<name>.yaml`).

   Give a recommended answer + one-line why for each question. Skip questions the code already answers.

4. **Preview the deterministic initializer.** Run the bundled script with `--dry-run` and the aligned inputs:

   ```bash
   bash scripts/init-repo-agents.sh \
     --target "$REPO_ROOT" \
     --project-name "$PROJECT_NAME" \
     --purpose "$ONE_LINE_PURPOSE" \
     --toolchain "$PRIMARY_TOOLCHAIN" \
     --entry-point "$ENTRY_POINT" \
     --dry-run
   ```

   Add `--scan-root <relative-path>` only when the default `src/` detection is not the correct shallow module boundary. Review the reported creates/updates/skips before continuing.

5. **Generate and verify.** Run the same command without `--dry-run`, then run:

   ```bash
   bash scripts/check-repo-agents.sh --target "$REPO_ROOT"
   ```

   A failed check means initialization is incomplete. Fix the script, template, assets, or explicit inputs; never repair the generated baseline by manually summarizing the template.

6. **Wrap up.** Summarize which files were created, updated, unchanged, or skipped, and give next-step pointers: run `grill` before large changes; after coding, pass the verification gate either with agent-run tests or a `cmd.md` user-test handoff; only then run `neat-freak` and `git-commit`; add a `docs/<module>.md` the first time a module is explored in depth; and adopt the `dev.sh` + YAML-driven experiments pattern from section 6 of the generated baseline.

## Rules

- All fixed output must come from `scripts/init-repo-agents.sh`. Never handwrite, copy from a Markdown fence, summarize, compress, or perform a second-pass rewrite of `references/AGENTS.template.md`.
- Idempotent and non-destructive: refresh only the initializer's managed block; preserve existing `AGENTS.md` and `CLAUDE.md` suffixes independently; create docs assets only when absent.
- Fresh `AGENTS.md` and `CLAUDE.md` files must be byte-identical. Existing files may differ outside their byte-identical managed blocks.
- Do not deep-read the codebase during init. Seed the index from a shallow structural scan only.
- Keep memory in-repo (`docs/`), never in a CLI-specific global memory, so it is portable.
- Language convention for generated files: agent-facing `AGENTS.md` and mirrored `CLAUDE.md` in English; user-facing `docs/`, `README.md`, and `cmd.md` in Chinese; code comments and agent-internal notes in English.
- The complete managed block in `AGENTS.template.md` is the top-level behavioral constraint. Its non-placeholder bytes must remain unchanged.
- Preserve the verification gate: candidate code must pass all required checks before `neat-freak`, completion logging, or `git-commit`. When the agent cannot run a required check, write the exact handoff to `cmd.md` and wait for the user's result.

## Resources

- `scripts/init-repo-agents.sh`: the only supported writer for the fixed baseline and scaffold.
- `scripts/check-repo-agents.sh`: read-only structural and template-fidelity validation.
- `references/AGENTS.template.md`: complete managed baseline template; scripts render its placeholders without model-authored rewriting.
- `references/docs-scaffold.md`: maintenance conventions for the assets and future memory entries.
- `assets/`: exact create-if-absent bodies for `docs/{plan,log,bug}.md` and root `cmd.md`.

## Completion Criteria

The repo is initialized when `scripts/check-repo-agents.sh` passes: both agent files contain the same complete managed baseline, fixed scaffold files exist with correct headers, the module index is seeded, no placeholders remain, and pre-existing suffix content was preserved.
