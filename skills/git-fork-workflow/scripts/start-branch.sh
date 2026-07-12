#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=false
PUSH=false
DEV_BRANCH="dev"
POSITIONAL=()

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
error() { printf '[ERROR] %s\n' "$*" >&2; }
success() { printf '[SUCCESS] %s\n' "$*"; }

usage() {
  cat <<'EOF'
Usage:
  start-branch.sh [options] feature <short-name>
  start-branch.sh [options] fix <short-name>

Update dev with a fast-forward-only pull, then create a topic branch.

Options:
  --dev <branch>  Development branch name (default: dev)
  --push          Push the new branch and set origin tracking
  --dry-run       Print planned commands without changing the repository
  --help          Show this help
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
  error "Not executed: all remaining branch creation and push steps."
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
  error "Not executed: all remaining branch creation and push steps."
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dev)
      [[ $# -ge 2 ]] || { error "--dev requires a branch."; usage >&2; exit 2; }
      DEV_BRANCH="$2"
      shift 2
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
    --)
      shift
      while [[ $# -gt 0 ]]; do
        POSITIONAL+=("$1")
        shift
      done
      ;;
    -*)
      error "Unknown option: $1"
      usage >&2
      exit 2
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

if [[ ${#POSITIONAL[@]} -ne 2 ]]; then
  error "Expected a branch type and short name."
  usage >&2
  exit 2
fi

BRANCH_TYPE="${POSITIONAL[0]}"
SHORT_NAME="${POSITIONAL[1]}"
if [[ "$BRANCH_TYPE" != "feature" && "$BRANCH_TYPE" != "fix" ]]; then
  error "Branch type must be 'feature' or 'fix'."
  usage >&2
  exit 2
fi

if [[ -z "$SHORT_NAME" ||
  ! "$SHORT_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ||
  "$SHORT_NAME" == *"//"* ]]; then
  error "Invalid branch short name: '$SHORT_NAME'."
  exit 2
fi

TARGET_BRANCH="$BRANCH_TYPE/$SHORT_NAME"
command -v git >/dev/null 2>&1 || { error "Git is not installed or not in PATH."; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
  { error "The current directory is not a Git worktree."; exit 1; }

git check-ref-format --branch "$DEV_BRANCH" >/dev/null 2>&1 ||
  fail "Invalid development branch name: $DEV_BRANCH" \
    "Choose a valid Git branch name and rerun." \
    "fetch, dev update, branch creation, and push."
git check-ref-format --branch "$TARGET_BRANCH" >/dev/null 2>&1 ||
  fail "Invalid target branch name: $TARGET_BRANCH" \
    "Use letters, digits, dots, underscores, or hyphens without unsafe Git ref sequences." \
    "fetch, dev update, branch creation, and push."

if [[ -n "$(git status --porcelain)" ]]; then
  fail "The worktree or index contains uncommitted changes." \
    "Commit or stash the changes, verify with 'git status', and rerun." \
    "fetch, dev update, branch creation, and push."
fi

remote_exists origin ||
  fail "Remote 'origin' does not exist." \
    "Add the fork as origin with 'git remote add origin <fork-url>'." \
    "fetch, dev update, branch creation, and push."

info "Repository: $(git rev-parse --show-toplevel)"
info "Current branch: $(git branch --show-current 2>/dev/null || true)"
info "Tracking branch: $(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || printf '%s' '<none>')"
info "Origin URL: $(git remote get-url origin)"
info "Planned branch: $TARGET_BRANCH from $DEV_BRANCH"

run git fetch origin "$DEV_BRANCH"

if [[ "$DRY_RUN" == false ]] && ! remote_branch_exists origin "$DEV_BRANCH"; then
  fail "Remote branch 'origin/$DEV_BRANCH' does not exist after fetch." \
    "Create and push $DEV_BRANCH first, or rerun with '--dev <existing-branch>'." \
    "dev update, branch creation, and push."
fi

if local_branch_exists "$TARGET_BRANCH" || remote_branch_exists origin "$TARGET_BRANCH"; then
  fail "Branch '$TARGET_BRANCH' already exists locally or on origin." \
    "Choose another short name or inspect the existing branch." \
    "dev update, branch creation, and push."
fi

if local_branch_exists "$DEV_BRANCH"; then
  run git switch "$DEV_BRANCH"
else
  run git switch -c "$DEV_BRANCH" --track "origin/$DEV_BRANCH"
fi
run git pull --ff-only origin "$DEV_BRANCH"
run git switch -c "$TARGET_BRANCH" "$DEV_BRANCH"

if [[ "$PUSH" == true ]]; then
  run git push -u origin "$TARGET_BRANCH"
else
  info "Push was not requested; origin was not changed."
fi

if [[ "$DRY_RUN" == true ]]; then
  success "Dry run completed; no repository changes were made."
else
  success "Created branch '$TARGET_BRANCH'."
fi
