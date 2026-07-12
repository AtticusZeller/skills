#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=false
PUSH=false
DEV_BRANCH="dev"
MAIN_BRANCH=""
UPSTREAM_URL=""

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
error() { printf '[ERROR] %s\n' "$*" >&2; }
success() { printf '[SUCCESS] %s\n' "$*"; }

usage() {
  cat <<'EOF'
Usage: init-fork.sh --upstream <url> [options]

Initialize a clone of a GitHub fork with upstream and dev branches.

Options:
  --upstream <url>  Official repository URL (required)
  --dev <branch>    Development branch name (default: dev)
  --main <branch>   Official default branch (auto-detected when omitted)
  --push            Push main and dev to origin and set dev tracking
  --dry-run         Print planned commands without changing the repository
  --help            Show this help
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
  error "Not executed: all remaining initialization steps."
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
  error "Not executed: all remaining initialization steps."
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

branch_namespace_conflict() {
  local branch="$1"
  local ref=""
  local candidate=""

  while IFS= read -r ref; do
    candidate="${ref#origin/}"
    if [[ "$candidate" == "$branch/"* || "$branch" == "$candidate/"* ]]; then
      printf '%s\n' "$ref"
      return 0
    fi
  done < <(
    {
      git for-each-ref --format='%(refname:short)' refs/heads
      git for-each-ref --format='%(refname:short)' refs/remotes/origin
    } | awk '!seen[$0]++'
  )
  return 1
}

require_branch_name() {
  local branch="$1"
  if ! git check-ref-format --branch "$branch" >/dev/null 2>&1; then
    fail "Invalid branch name: $branch" \
      "Choose a valid Git branch name and rerun the command." \
      "remote changes, fetches, branch changes, and pushes."
  fi
}

require_clean_worktree() {
  if [[ -n "$(git status --porcelain)" ]]; then
    fail "The worktree or index contains uncommitted changes." \
      "Commit or stash the changes, verify with 'git status', and rerun." \
      "remote changes, fetches, branch changes, and pushes."
  fi
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

  if [[ -z "$detected" ]] && remote_exists upstream; then
    detected="$(
      git remote show upstream 2>/dev/null |
        awk '/^[[:space:]]*HEAD branch:/ { print $NF; exit }'
    )"
  fi

  if [[ -z "$detected" ]]; then
    detected="$(
      git ls-remote --symref "$UPSTREAM_URL" HEAD 2>/dev/null |
        awk '$1 == "ref:" { sub("^refs/heads/", "", $2); print $2; exit }'
    )"
  fi

  if [[ -z "$detected" || "$detected" == "(unknown)" ]]; then
    fail "Could not detect the upstream default branch." \
      "Inspect 'git remote show upstream' and rerun with '--main <branch>'." \
      "main synchronization, dev creation, and pushes."
  fi
  printf '%s\n' "$detected"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --upstream)
      [[ $# -ge 2 ]] || { error "--upstream requires a URL."; usage >&2; exit 2; }
      UPSTREAM_URL="$2"
      shift 2
      ;;
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

[[ -n "$UPSTREAM_URL" ]] || { error "--upstream is required."; usage >&2; exit 2; }
command -v git >/dev/null 2>&1 || { error "Git is not installed or not in PATH."; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
  { error "The current directory is not a Git worktree."; exit 1; }

require_clean_worktree
require_branch_name "$DEV_BRANCH"
[[ -z "$MAIN_BRANCH" ]] || require_branch_name "$MAIN_BRANCH"

info "Repository: $(git rev-parse --show-toplevel)"
info "Current branch: $(git branch --show-current 2>/dev/null || true)"
info "Tracking branch: $(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || printf '%s' '<none>')"
info "Current remotes:"
git remote -v

remote_exists origin ||
  fail "Remote 'origin' does not exist." \
    "Add the fork as origin with 'git remote add origin <fork-url>'." \
    "upstream configuration, fetches, branch changes, and pushes."

if remote_exists upstream; then
  existing_upstream="$(git remote get-url upstream)"
  if [[ "$existing_upstream" != "$UPSTREAM_URL" ]]; then
    fail "Remote 'upstream' URL mismatch: expected '$UPSTREAM_URL', found '$existing_upstream'." \
      "Verify both URLs; if appropriate, change it explicitly with 'git remote set-url upstream <url>'." \
      "fetches, branch changes, and pushes."
  fi
  info "Remote 'upstream' already has the expected URL."
else
  run git remote add upstream "$UPSTREAM_URL"
fi

run git fetch upstream --tags --prune
run git fetch origin --prune

MAIN_BRANCH="$(detect_default_branch)"
require_branch_name "$MAIN_BRANCH"
info "Official default branch: $MAIN_BRANCH"

if [[ "$DRY_RUN" == false ]] && ! remote_branch_exists upstream "$MAIN_BRANCH"; then
  fail "Remote branch 'upstream/$MAIN_BRANCH' does not exist after fetch." \
    "Inspect 'git remote show upstream' and rerun with the correct '--main' value." \
    "main synchronization, dev creation, and pushes."
fi

if remote_branch_exists origin "$MAIN_BRANCH" && remote_branch_exists upstream "$MAIN_BRANCH"; then
  read -r _ origin_only < <(
    git rev-list --left-right --count "upstream/$MAIN_BRANCH...origin/$MAIN_BRANCH"
  )
  if (( origin_only > 0 )); then
    fail "origin/$MAIN_BRANCH contains $origin_only commit(s) absent from upstream/$MAIN_BRANCH." \
      "Inspect 'git log --oneline --left-right upstream/$MAIN_BRANCH...origin/$MAIN_BRANCH' and preserve personal commits on dev or a topic branch." \
      "local main changes, dev creation, and pushes."
  fi
fi

if ! local_branch_exists "$DEV_BRANCH" && ! remote_branch_exists origin "$DEV_BRANCH"; then
  if namespace_ref="$(branch_namespace_conflict "$DEV_BRANCH")"; then
    fail "Branch '$DEV_BRANCH' conflicts with existing ref '$namespace_ref'." \
      "Choose a non-conflicting development branch, for example '--dev personal-dev'." \
      "local main changes, dev creation, and pushes."
  fi
fi

if local_branch_exists "$MAIN_BRANCH"; then
  if remote_branch_exists upstream "$MAIN_BRANCH"; then
    read -r local_only upstream_only < <(
      git rev-list --left-right --count "$MAIN_BRANCH...upstream/$MAIN_BRANCH"
    )
    if (( local_only > 0 )); then
      fail "Local $MAIN_BRANCH contains $local_only commit(s) absent from upstream/$MAIN_BRANCH; it is not a clean mirror." \
        "Inspect 'git log --oneline --left-right upstream/$MAIN_BRANCH...$MAIN_BRANCH' and preserve personal commits on dev or a topic branch." \
        "main synchronization, dev creation, and pushes."
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

if local_branch_exists "$DEV_BRANCH"; then
  info "Local $DEV_BRANCH already exists; leaving it unchanged."
  run git switch "$DEV_BRANCH"
elif remote_branch_exists origin "$DEV_BRANCH"; then
  run git switch -c "$DEV_BRANCH" --track "origin/$DEV_BRANCH"
else
  run git switch -c "$DEV_BRANCH" "$MAIN_BRANCH"
fi

if [[ "$PUSH" == true ]]; then
  run git push origin "$MAIN_BRANCH:$MAIN_BRANCH"
  run git push -u origin "$DEV_BRANCH"
else
  info "Push was not requested; origin branches were not changed."
fi

if [[ "$DRY_RUN" == true ]]; then
  success "Dry run completed; no repository changes were made."
else
  success "Fork initialization completed."
fi
