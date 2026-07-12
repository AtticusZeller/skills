#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=false
PUSH=false
SYNC_DEV=true
DEV_BRANCH="dev"
MAIN_BRANCH=""

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
error() { printf '[ERROR] %s\n' "$*" >&2; }
success() { printf '[SUCCESS] %s\n' "$*"; }

usage() {
  cat <<'EOF'
Usage: sync-upstream.sh [options]

Fast-forward the clean main branch from upstream, then merge main into dev.

Options:
  --dev <branch>   Development branch name (default: dev)
  --main <branch>  Official default branch (auto-detected when omitted)
  --no-dev         Update main only
  --push           Push updated main and dev to origin after local success
  --dry-run        Print planned commands without changing the repository
  --help           Show this help
EOF
}

print_command() {
  printf '[INFO] $'
  printf ' %q' "$@"
  printf '\n'
}

run() {
  local status=0
  print_command "$@"
  if [[ "$DRY_RUN" == true ]]; then
    return 0
  fi
  if "$@"; then
    return 0
  else
    status=$?
  fi
  error "Command failed with exit status $status: $*"
  error "Current repository status:"
  repo_snapshot >&2
  error "Recommended manual action: inspect the Git error above and run 'git status' before retrying."
  error "Not executed: all remaining synchronization, restoration, and push steps."
  exit "$status"
}

repo_snapshot() {
  git status --short --branch 2>/dev/null || true
  git remote -v 2>/dev/null || true
  git branch -vv 2>/dev/null || true
}

fail() {
  local problem="$1"
  local recommendation="$2"
  local pending="$3"
  error "$problem"
  error "Current repository status:"
  repo_snapshot >&2
  error "Recommended manual action: $recommendation"
  error "Not executed: $pending"
  exit 1
}

unexpected_failure() {
  local status="$1"
  local line="$2"
  trap - ERR
  error "A command failed with exit status ${status} at line ${line}."
  error "Current repository status:"
  repo_snapshot >&2
  error "Recommended manual action: inspect the Git error above, then run 'git status' and 'git branch -vv'."
  error "Not executed: all remaining synchronization, restoration, and push steps."
  exit "$status"
}
trap 'unexpected_failure "$?" "$LINENO"' ERR

remote_exists() {
  git remote get-url "$1" >/dev/null 2>&1
}

local_branch_exists() {
  git show-ref --verify --quiet "refs/heads/$1"
}

remote_branch_exists() {
  git show-ref --verify --quiet "refs/remotes/$1/$2"
}

detect_default_branch() {
  local detected=""
  local symbolic=""

  if [[ -n "$MAIN_BRANCH" ]]; then
    printf '%s\n' "$MAIN_BRANCH"
    return 0
  fi

  symbolic="$(git symbolic-ref --quiet refs/remotes/upstream/HEAD 2>/dev/null || true)"
  if [[ -n "$symbolic" ]]; then
    detected="${symbolic#refs/remotes/upstream/}"
  fi
  if [[ -z "$detected" ]]; then
    detected="$(
      git remote show upstream 2>/dev/null |
        awk '/^[[:space:]]*HEAD branch:/ { print $NF; exit }'
    )"
  fi
  if [[ -z "$detected" || "$detected" == "(unknown)" ]]; then
    fail "Could not detect the upstream default branch." \
      "Inspect 'git remote show upstream' and rerun with '--main <branch>'." \
      "main and dev synchronization and pushes."
  fi
  printf '%s\n' "$detected"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dev)
      [[ $# -ge 2 ]] || { error "--dev requires a branch."; usage >&2; exit 2; }
      DEV_BRANCH="$2"
      shift 2
      ;;
    --main)
      [[ $# -ge 2 ]] || { error "--main requires a branch."; usage >&2; exit 2; }
      MAIN_BRANCH="$2"
      shift 2
      ;;
    --no-dev)
      SYNC_DEV=false
      shift
      ;;
    --push)
      PUSH=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      error "Unknown argument: $1"
      usage >&2
      exit 2
      ;;
  esac
done

command -v git >/dev/null 2>&1 || { error "Git is not installed or not in PATH."; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
  { error "The current directory is not a Git worktree."; exit 1; }

git check-ref-format --branch "$DEV_BRANCH" >/dev/null 2>&1 ||
  fail "Invalid development branch name: $DEV_BRANCH" \
    "Choose a valid Git branch name and rerun." \
    "fetch, synchronization, and pushes."
[[ -z "$MAIN_BRANCH" ]] || git check-ref-format --branch "$MAIN_BRANCH" >/dev/null 2>&1 ||
  fail "Invalid main branch name: $MAIN_BRANCH" \
    "Choose a valid Git branch name and rerun." \
    "fetch, synchronization, and pushes."

if [[ -n "$(git status --porcelain)" ]]; then
  fail "The worktree or index contains uncommitted changes." \
    "Commit or stash the changes, verify with 'git status', and rerun." \
    "fetch, branch synchronization, and pushes."
fi

remote_exists origin ||
  fail "Remote 'origin' does not exist." \
    "Add the fork as origin with 'git remote add origin <fork-url>'." \
    "fetch, branch synchronization, and pushes."
remote_exists upstream ||
  fail "Remote 'upstream' does not exist." \
    "Run init-fork.sh with the official repository URL." \
    "fetch, branch synchronization, and pushes."

ORIGINAL_BRANCH="$(git branch --show-current 2>/dev/null || true)"
ORIGINAL_COMMIT="$(git rev-parse HEAD)"
info "Repository: $(git rev-parse --show-toplevel)"
info "Original branch: ${ORIGINAL_BRANCH:-<detached at $ORIGINAL_COMMIT>}"
info "Tracking branch: $(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || printf '%s' '<none>')"
info "Origin URL: $(git remote get-url origin)"
info "Upstream URL: $(git remote get-url upstream)"

run git fetch upstream --tags --prune
run git fetch origin --prune

MAIN_BRANCH="$(detect_default_branch)"
git check-ref-format --branch "$MAIN_BRANCH" >/dev/null 2>&1 ||
  fail "Detected invalid upstream default branch: $MAIN_BRANCH" \
    "Inspect 'git remote show upstream' and rerun with '--main <branch>'." \
    "main and dev synchronization and pushes."
info "Official default branch: $MAIN_BRANCH"

if [[ "$DRY_RUN" == false ]] && ! remote_branch_exists upstream "$MAIN_BRANCH"; then
  fail "Remote branch 'upstream/$MAIN_BRANCH' does not exist after fetch." \
    "Inspect 'git remote show upstream' and rerun with the correct '--main' value." \
    "main and dev synchronization and pushes."
fi

if remote_branch_exists origin "$MAIN_BRANCH" && remote_branch_exists upstream "$MAIN_BRANCH"; then
  read -r _ origin_only < <(
    git rev-list --left-right --count "upstream/$MAIN_BRANCH...origin/$MAIN_BRANCH"
  )
  if (( origin_only > 0 )); then
    fail "origin/$MAIN_BRANCH contains $origin_only commit(s) absent from upstream/$MAIN_BRANCH." \
      "Inspect 'git log --oneline --left-right upstream/$MAIN_BRANCH...origin/$MAIN_BRANCH' and preserve personal commits on dev or a topic branch." \
      "local synchronization and pushes."
  fi
fi

if local_branch_exists "$MAIN_BRANCH"; then
  if remote_branch_exists upstream "$MAIN_BRANCH"; then
    read -r local_only upstream_only < <(
      git rev-list --left-right --count "$MAIN_BRANCH...upstream/$MAIN_BRANCH"
    )
    if (( local_only > 0 )); then
      fail "Local $MAIN_BRANCH contains $local_only commit(s) absent from upstream/$MAIN_BRANCH." \
        "Inspect 'git log --oneline --left-right upstream/$MAIN_BRANCH...$MAIN_BRANCH' and preserve personal commits before manual repair." \
        "main and dev synchronization and pushes."
    fi
    run git switch "$MAIN_BRANCH"
    if (( upstream_only > 0 )); then
      run git merge --ff-only "upstream/$MAIN_BRANCH"
    else
      info "Local $MAIN_BRANCH is already synchronized."
    fi
  else
    run git switch "$MAIN_BRANCH"
    print_command git merge --ff-only "upstream/$MAIN_BRANCH"
  fi
else
  run git switch -c "$MAIN_BRANCH" --track "upstream/$MAIN_BRANCH"
fi

if [[ "$SYNC_DEV" == true ]]; then
  if local_branch_exists "$DEV_BRANCH"; then
    run git switch "$DEV_BRANCH"
  elif remote_branch_exists origin "$DEV_BRANCH"; then
    run git switch -c "$DEV_BRANCH" --track "origin/$DEV_BRANCH"
  elif [[ "$DRY_RUN" == true ]]; then
    print_command git switch "$DEV_BRANCH"
  else
    fail "Development branch '$DEV_BRANCH' does not exist locally or on origin." \
      "Run init-fork.sh first or rerun with '--dev <existing-branch>'." \
      "merge into dev, original branch restoration, and pushes."
  fi

  if local_branch_exists "$DEV_BRANCH" && git merge-base --is-ancestor "$MAIN_BRANCH" "$DEV_BRANCH"; then
    info "$DEV_BRANCH already contains $MAIN_BRANCH; no merge commit is needed."
  else
    print_command git merge "$MAIN_BRANCH"
    if [[ "$DRY_RUN" == false ]] && ! git merge "$MAIN_BRANCH"; then
      error "Merging $MAIN_BRANCH into $DEV_BRANCH failed, possibly due to conflicts."
      git status >&2
      error "Recommended manual action: resolve conflicts and commit, or explicitly run 'git merge --abort'."
      error "Not executed: original branch restoration and all pushes."
      exit 1
    fi
  fi
fi

if [[ -n "$ORIGINAL_BRANCH" && "$ORIGINAL_BRANCH" != "$MAIN_BRANCH" && "$ORIGINAL_BRANCH" != "$DEV_BRANCH" ]]; then
  run git switch "$ORIGINAL_BRANCH"
elif [[ -z "$ORIGINAL_BRANCH" ]]; then
  run git switch --detach "$ORIGINAL_COMMIT"
fi

if [[ "$PUSH" == true ]]; then
  run git push origin "$MAIN_BRANCH:$MAIN_BRANCH"
  if [[ "$SYNC_DEV" == true ]]; then
    run git push origin "$DEV_BRANCH:$DEV_BRANCH"
  fi
else
  info "Push was not requested; origin branches were not changed."
fi

if [[ "$DRY_RUN" == true ]]; then
  success "Dry run completed; no repository changes were made."
else
  success "Upstream synchronization completed."
fi
