#!/usr/bin/env bash
set -euo pipefail

FETCH=false
DEV_BRANCH="dev"
MAIN_BRANCH=""

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
error() { printf '[ERROR] %s\n' "$*" >&2; }
success() { printf '[SUCCESS] %s\n' "$*"; }

usage() {
  cat <<'EOF'
Usage: fork-status.sh [options]

Display fork remotes, tracking, and branch divergence without changing branches.

Options:
  --dev <branch>   Development branch name (default: dev)
  --main <branch>  Official default branch (auto-detected when omitted)
  --fetch          Fetch origin and upstream before reporting
  --help           Show this help

Without --fetch, this script performs no repository writes and reports from
existing remote-tracking refs.
EOF
}

print_command() {
  printf '[INFO] $'
  printf ' %q' "$@"
  printf '\n'
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
  error "Recommended manual action: inspect the Git error above and verify remote connectivity."
  error "Not executed: the remainder of the status report."
  exit "$status"
}
trap 'unexpected_failure "$?" "$LINENO"' ERR

remote_exists() {
  git remote get-url "$1" >/dev/null 2>&1
}

ref_exists() {
  git rev-parse --verify --quiet "$1^{commit}" >/dev/null 2>&1
}

detect_default_branch() {
  local symbolic=""
  local detected=""

  if [[ -n "$MAIN_BRANCH" ]]; then
    printf '%s\n' "$MAIN_BRANCH"
    return 0
  fi
  if ! remote_exists upstream; then
    printf '%s\n' "<unknown>"
    return 0
  fi

  symbolic="$(git symbolic-ref --quiet refs/remotes/upstream/HEAD 2>/dev/null || true)"
  if [[ -n "$symbolic" ]]; then
    detected="${symbolic#refs/remotes/upstream/}"
  fi
  if [[ -z "$detected" ]]; then
    detected="$(
      git ls-remote --symref upstream HEAD 2>/dev/null |
        awk '$1 == "ref:" { sub("^refs/heads/", "", $2); print $2; exit }'
    )"
  fi
  printf '%s\n' "${detected:-<unknown>}"
}

print_divergence() {
  local label="$1"
  local base="$2"
  local subject="$3"
  local behind=""
  local ahead=""

  if ! ref_exists "$base" || ! ref_exists "$subject"; then
    printf '%-34s unavailable (missing %s or %s)\n' "$label" "$base" "$subject"
    return 0
  fi
  read -r behind ahead < <(git rev-list --left-right --count "$base...$subject")
  printf '%-34s ahead=%s behind=%s\n' "$label" "$ahead" "$behind"
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
    --fetch)
      FETCH=true
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

if [[ "$FETCH" == true ]]; then
  if remote_exists origin; then
    print_command git fetch origin --prune
    git fetch origin --prune
  fi
  if remote_exists upstream; then
    print_command git fetch upstream --tags --prune
    git fetch upstream --tags --prune
  fi
fi

MAIN_BRANCH="$(detect_default_branch)"
CURRENT_BRANCH="$(git branch --show-current 2>/dev/null || true)"
CURRENT_COMMIT="$(git rev-parse --short HEAD)"
ROOT="$(git rev-parse --show-toplevel)"
if [[ -z "$(git status --porcelain)" ]]; then
  WORKTREE_STATE="clean"
else
  WORKTREE_STATE="dirty"
fi

if remote_exists origin; then
  ORIGIN_URL="$(git remote get-url origin)"
else
  ORIGIN_URL="<missing>"
  warn "Remote 'origin' is missing."
fi
if remote_exists upstream; then
  UPSTREAM_URL="$(git remote get-url upstream)"
else
  UPSTREAM_URL="<missing>"
  warn "Remote 'upstream' is missing."
fi

TRACKING="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
if [[ -z "$TRACKING" ]]; then
  TRACKING="<none>"
  UNPUSHED="unknown (current branch has no tracking branch)"
elif ref_exists '@{upstream}'; then
  UNPUSHED_COUNT="$(git rev-list --count '@{upstream}..HEAD')"
  if (( UNPUSHED_COUNT > 0 )); then
    UNPUSHED="yes ($UNPUSHED_COUNT commit(s))"
  else
    UNPUSHED="no"
  fi
else
  UNPUSHED="unknown (tracking ref is missing)"
fi

GONE_TRACKING="$(
  git for-each-ref \
    --format='%(refname:short) %(upstream:short) %(upstream:track)' refs/heads |
    awk '$NF == "[gone]" { print $1 " -> " $2 }'
)"

printf 'Fork status\n'
printf '  Repository:              %s\n' "$ROOT"
printf '  Current branch:          %s\n' "${CURRENT_BRANCH:-<detached at $CURRENT_COMMIT>}"
printf '  Worktree:                %s\n' "$WORKTREE_STATE"
printf '  Origin URL:              %s\n' "$ORIGIN_URL"
printf '  Upstream URL:            %s\n' "$UPSTREAM_URL"
printf '  Official default branch: %s\n' "$MAIN_BRANCH"
printf '  Tracking branch:         %s\n' "$TRACKING"
printf '  Unpushed commits:        %s\n' "$UNPUSHED"
printf '\nDivergence\n'

if [[ "$MAIN_BRANCH" == "<unknown>" ]]; then
  printf '%-34s unavailable (default branch unknown)\n' "local main vs upstream"
  printf '%-34s unavailable (default branch unknown)\n' "origin main vs upstream"
  printf '%-34s unavailable (default branch unknown)\n' "dev vs main"
else
  print_divergence "local $MAIN_BRANCH vs upstream" "upstream/$MAIN_BRANCH" "$MAIN_BRANCH"
  print_divergence "origin/$MAIN_BRANCH vs upstream" "upstream/$MAIN_BRANCH" "origin/$MAIN_BRANCH"
  print_divergence "$DEV_BRANCH vs $MAIN_BRANCH" "$MAIN_BRANCH" "$DEV_BRANCH"
fi

printf '\nGone tracking branches\n'
if [[ -n "$GONE_TRACKING" ]]; then
  printf '%s\n' "$GONE_TRACKING"
else
  printf '  none\n'
fi

if [[ "$FETCH" == true ]]; then
  success "Status report completed after fetching remotes."
else
  info "Remote-tracking refs were not fetched; use --fetch for current remote data."
  success "Read-only status report completed."
fi
