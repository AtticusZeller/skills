---
name: init-repo-agents
description: Initialize or update repository-level agent collaboration scaffolding for a new or existing project. Use whenever the user wants to set up or refresh AGENTS.md / CLAUDE.md baseline rules, bootstrap a repo's agent config, define Type B / C− / C alignment, verification, and Explain Diff understanding gates, track cognitive debt, create portable in-repo docs memory, create a cmd.md user-test handoff, or seed a docs/module-name.md code-doc index. Trigger on phrases like "初始化这个仓库", "更新仓库 AGENTS.md", "给项目配 AGENTS.md", "init repo agents", "update repo agents", or "set up the project memory/docs". Prefer this skill over ad-hoc edits to its managed block.
---

# Init Repo Agents

## Overview

Use this skill to give any repository a portable, self-contained agent baseline in a single pass. The output lives **inside the repo** (`AGENTS.md`, mirrored `CLAUDE.md`, and `docs/`) rather than in a CLI-specific global memory, so the same context follows the project across machines and across agents (Codex, Claude Code, etc.).

The skill confirms the user's global skills, gathers the small set of project facts needed by the template, and then delegates all fixed file generation to `scripts/init-repo-agents.sh`. The script renders the complete baseline rules, scaffolds the in-repo memory files, creates `cmd.md`, and seeds a lazy code-doc index. It deliberately does **not** deep-read the codebase to auto-generate module docs — those are filled incrementally as work happens, to avoid re-reading a large repo up front.

Treat running this skill as a setup task: it is idempotent and must never clobber content the user already wrote.

## Workflow

Execute these steps in order. Resolve every bundled path relative to this `SKILL.md`, not relative to the target repository.

1. **Choose init or update.** Identify the target repository root and inspect `AGENTS.md`, `CLAUDE.md`, `docs/`, and `cmd.md` without rewriting them.
   - If the managed block is absent, follow the initialization workflow below.
   - If the repository was already initialized and the user wants the latest global baseline, run the bundled updater. It recovers project facts and the module index from the current managed block, refreshes only that block, preserves both files' independent suffixes, and creates only newly introduced scaffold assets.

   To preview from the currently installed skill:

   ```bash
   bash scripts/update-repo-agents.sh --target "$REPO_ROOT" --dry-run
   ```

   To install or update both required global personal skills and then refresh the
   repository:

   ```bash
   bash scripts/update-repo-agents.sh \
     --target "$REPO_ROOT" \
     --refresh-skill
   ```

   After a successful update, skip to Wrap up.

2. **Verify global skills.** Confirm the user's personal global skills are installed:

   ```bash
   npx skills add AtticusZeller/skills --list --full-depth
   ```

   The baseline rules reference global skills — confirm the ones this project will lean on are present: `explain-diff-html`, `neat-freak`, `karpathy-guidelines`, `modern-python` (for Python projects), `find-docs` / `context7-cli` (`ctx7`), `git-commit`, `gh-cli`. If Explain Diff is missing, install the mirrored personal skills:

   ```bash
   npx skills add AtticusZeller/skills \
     --skill explain-diff-html explain-diff-notion \
     -g -a codex claude-code cursor -y --full-depth
   ```

   For missing external skills, use the sources recorded in this repository's
   `manifests/global-skills.json` when the repository checkout is available.

   Note: `grill` is not a globally installed skill, so its workflow is embedded directly in `references/AGENTS.template.md` and needs no install.

3. **Lightweight setup alignment (grill).** Ask the smallest useful batch of related questions for arguments you cannot get by reading the repo or its docs, and iterate only when answers expose another gap:
   - Project name and one-line purpose.
   - Primary language and toolchain (e.g. Python + uv/ruff/ty, Node + pnpm).
   - The unified entry point (prefer `dev.sh`) and whether experiments are driven by YAML configs (e.g. `experiments/<name>.yaml`).

   Give a recommended answer + one-line why for each choice. Skip factual questions the code already answers, incorporate multiple answers from one response, and do not re-ask resolved questions.

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

6. **Wrap up.** Summarize which files were created, updated, unchanged, or skipped. Explain the generated lifecycle: Type B is the fast path with user verification by default; Type C− requires pre-code alignment and user verification, then records cognitive debt and commits without immediate Explain Diff; Type C adds the `explain-diff-html` five-question human review before closeout. Add a `docs/<module>.md` the first time a module is explored in depth.

## Rules

- All fixed output must come from `scripts/init-repo-agents.sh`. Never handwrite, copy from a Markdown fence, summarize, compress, or perform a second-pass rewrite of `references/AGENTS.template.md`.
- Idempotent and non-destructive: refresh only the initializer's managed block; preserve existing `AGENTS.md` and `CLAUDE.md` suffixes independently; create docs assets only when absent.
- Update mode must recover project facts and preserve the existing module index; it must not force the user through initialization questions again.
- Fresh `AGENTS.md` and `CLAUDE.md` files must be byte-identical. Existing files may differ outside their byte-identical managed blocks.
- Do not deep-read the codebase during init. Seed the index from a shallow structural scan only.
- Keep memory in-repo (`docs/`), never in a CLI-specific global memory, so it is portable.
- Language convention for generated files: agent-facing `AGENTS.md` and mirrored `CLAUDE.md` in English; user-facing `docs/`, `README.md`, and `cmd.md` in Chinese; code comments and agent-internal notes in English.
- The complete managed block in `AGENTS.template.md` is the top-level behavioral constraint. Its non-placeholder bytes must remain unchanged.
- Preserve the lifecycle distinctions: Type B skips alignment and understanding review; Type C− and C require explicit pre-code alignment; Type C− records cognitive debt instead of immediate understanding review; Type C must pass `explain-diff-html`; Type C− and C require user-run verification, and Type B requires it by default.

## Resources

- `scripts/init-repo-agents.sh`: the only supported writer for the fixed baseline and scaffold.
- `scripts/update-repo-agents.sh`: refreshes the global skill on request and updates an initialized repository without recollecting facts.
- `scripts/check-repo-agents.sh`: read-only structural and template-fidelity validation.
- `references/AGENTS.template.md`: complete managed baseline template; scripts render its placeholders without model-authored rewriting.
- `references/docs-scaffold.md`: maintenance conventions for the assets and future memory entries.
- `assets/`: exact create-if-absent bodies for `docs/{plan,log,bug}.md` and root `cmd.md`.

## Completion Criteria

The repo is initialized when `scripts/check-repo-agents.sh` passes: both agent files contain the same complete managed baseline, fixed scaffold files exist with correct headers, the module index is seeded, no placeholders remain, and pre-existing suffix content was preserved.
