---
name: git-fork-workflow
description: Initialize and maintain GitHub fork repositories with a clean upstream-tracking main branch, a long-lived dev branch, and feature or fix branches. Use when configuring remotes after cloning a fork, synchronizing upstream releases and patches, creating development branches, or diagnosing fork divergence.
---

# Git Fork Workflow

Maintain this branch model:

```text
upstream/main -> origin/main -> origin/dev -> feature/* or fix/*
```

Keep `main` as a clean mirror of the official repository. Develop only on `dev`,
`feature/*`, or `fix/*`. Merge shared branches; do not rebase commits that have
already been pushed.

Initialize only the long-lived development branch by default. Create a
`feature/*` or `fix/*` branch only when the user explicitly asks to begin that
specific work; do not create topic branches merely to initialize or validate a
fork.

## Inspect before changing anything

Before any write operation:

1. Confirm the current directory is a Git repository.
2. Require a clean worktree and index.
3. Show the current remotes and their URLs.
4. Show the current branch and its upstream tracking branch.
5. Confirm `origin` exists.
6. Confirm or configure `upstream` only with the user's expected URL.
7. Detect whether the official default branch is `main` or another name.
8. Show the exact operation and command sequence that will run. Offer
   `--dry-run` when supported, and obtain user confirmation before changing a
   remote, creating a branch, or pushing.

Prefer the bundled scripts over assembling ad hoc Git command sequences:

- Run `scripts/init-fork.sh --upstream <url>` after cloning a fork.
- Run `scripts/sync-upstream.sh` to update the clean main branch and merge it
  into dev.
- Run `scripts/start-branch.sh feature <name>` or
  `scripts/start-branch.sh fix <name>` to begin work.
- Run `scripts/fork-status.sh` for read-only diagnosis; add `--fetch` only when
  current remote data is needed.

Read [references/workflow.md](references/workflow.md) when explaining the model,
resolving divergence, or guiding manual conflict handling.

## Stop safely

Stop without overriding anything when:

- the worktree or index contains uncommitted changes;
- local main and upstream main have diverged;
- origin main contains commits absent from upstream main;
- a merge reports conflicts;
- an existing remote URL differs from the expected URL; or
- the requested branch name conflicts with an existing branch.

Treat ref namespace collisions as branch conflicts. For example, an existing
`dev/topic` prevents creating `dev`; ask the user for an alternative such as
`personal-dev` instead of attempting the push.

Do not default to `git reset --hard`, `git push --force`,
`git push --force-with-lease`, deleting a remote branch, deleting an unmerged
branch, overwriting uncommitted work, or changing global Git configuration.
Do not automatically abort a conflicted merge.

## Report failures

For every failure, report:

1. the detected problem;
2. the current repository status;
3. recommended manual inspection or recovery commands; and
4. which planned operations were not executed.

Preserve Git's original error output and return a nonzero status for failed
script operations.
