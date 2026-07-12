# GitHub Fork Workflow

## Remote and branch model

```text
upstream/main
     |
     v
origin/main
     |
     v
origin/dev
     |
     +-- feature/*
     `-- fix/*
```

- `upstream` points to the official repository.
- `origin` points to the user's fork.
- `main` mirrors the official default branch and contains no personal work.
- `dev` is the long-lived integration branch for personal changes.
- `feature/*` and `fix/*` start from an up-to-date `dev`.

Replace `main` in these examples if the official repository uses another
default branch.

## Initialize a cloned fork

From a clean clone of the fork, preview and then initialize:

```bash
scripts/init-fork.sh --upstream https://github.com/OWNER/PROJECT.git --dry-run
scripts/init-fork.sh --upstream https://github.com/OWNER/PROJECT.git --push
```

The script adds `upstream` only when absent, fetches its branches and tags,
fast-forwards local `main`, and creates `dev` only when it does not already
exist. Re-running it preserves an existing correct configuration.

Initialization creates only the long-lived development branch. Do not create
`feature/*` or `fix/*` branches as setup or validation artifacts. If the
upstream already has branches such as `dev/topic`, Git cannot also create a
branch named `dev`; choose an explicit alternative:

```bash
scripts/init-fork.sh \
  --upstream https://github.com/OWNER/PROJECT.git \
  --dev personal-dev \
  --push
```

## Synchronize upstream changes

Preview and then synchronize:

```bash
scripts/sync-upstream.sh --dry-run
scripts/sync-upstream.sh --push
```

The script fetches upstream, fast-forwards `main` from `upstream/main`, merges
`main` into `dev`, and pushes only after all local operations succeed. Use
`--no-dev` when only the clean mirror should be updated.

## Start feature and fix work

Create a topic branch only when beginning explicitly requested work, and base
it on the latest fast-forwarded development branch:

```bash
scripts/start-branch.sh feature custom-reward --push
scripts/start-branch.sh fix dataloader-crash --push
```

Merge completed branches through the project's normal review process. Do not
develop directly on `main`.

## Choose merge or rebase

Use merge by default for `main` into `dev` and for branches that have already
been shared. Merge preserves public history and avoids requiring collaborators
to reconcile rewritten commits.

Use rebase only for private, unpushed work when the user explicitly requests
history cleanup and understands that commit IDs will change. Never rebase
published `main` or `dev` as part of this workflow.

## Handle a diverged main

If local `main` or `origin/main` contains commits absent from upstream, stop and
inspect before changing history:

```bash
git status --short --branch
git log --oneline --left-right upstream/main...main
git log --oneline --left-right upstream/main...origin/main
git branch backup/main-before-repair main
```

Decide manually whether personal commits should be moved to `dev` or a topic
branch. Do not repair the divergence with `git reset --hard` or a force push by
default. After preserving the commits, choose an explicit recovery method with
the user.

## Handle merge conflicts

When a merge into `dev` conflicts:

```bash
git status
git diff --name-only --diff-filter=U
```

Resolve each file, stage the resolutions, and finish with `git commit`. To
discard the in-progress merge, the user may explicitly run:

```bash
git merge --abort
```

The scripts do not abort automatically because doing so can discard conflict
resolution work already performed by the user.

## Common diagnostics

```bash
scripts/fork-status.sh
scripts/fork-status.sh --fetch
git remote -v
git branch -vv
git rev-list --left-right --count upstream/main...main
git rev-list --left-right --count upstream/main...origin/main
git rev-list --left-right --count main...dev
```

Direct work on `main` makes it cease to be a trustworthy mirror, complicates
upstream synchronization, and can require history rewriting to repair the
fork. Keeping personal work on `dev` and topic branches makes divergence
visible and recovery safer.
