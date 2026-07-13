#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
prompt_file="${script_dir}/../assets/dsw-persistent-prompt.md"
target_home="${HOME}"
dry_run=false

usage() {
  cat <<'EOF'
Usage: install-dsw-persistent-prompt.sh [options]

Append the Alibaba Cloud DSW persistent-storage prompt to Codex AGENTS.md.

Options:
  --target-home <dir>  Home directory receiving .codex/AGENTS.md (default: $HOME)
  --dry-run            Report changes without writing files
  -h, --help           Show this help
EOF
}

info() {
  printf '[INFO] %s\n' "$*"
}

die() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

require_value() {
  local option="$1"
  local remaining="$2"
  ((remaining >= 2)) || {
    printf '[ERROR] %s requires a value\n' "$option" >&2
    usage >&2
    exit 2
  }
}

while (($#)); do
  case "$1" in
    --target-home)
      require_value "$1" "$#"
      target_home="$2"
      shift 2
      ;;
    --dry-run)
      dry_run=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf '[ERROR] Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[[ -d "$target_home" ]] || die "Target home is not a directory: ${target_home}"
target_home="$(cd "$target_home" && pwd)"
[[ -w "$target_home" ]] || die "Target home is not writable: ${target_home}"
[[ -f "$prompt_file" ]] || die "Missing prompt asset: ${prompt_file}"

prompt="$(<"$prompt_file")"
[[ -n "$prompt" && "$prompt" != *$'\n'* && "$prompt" != *$'\r'* ]] ||
  die "Prompt asset must contain exactly one non-empty line"

agents_dir="${target_home}/.codex"
agents_file="${agents_dir}/AGENTS.md"

if [[ -f "$agents_file" ]] && grep -Fqx -- "$prompt" "$agents_file"; then
  info "DSW persistent storage prompt already present: ${agents_file}"
  exit 0
fi

if [[ -e "$agents_file" && ! -f "$agents_file" ]]; then
  die "Codex AGENTS path is not a regular file: ${agents_file}"
fi

if [[ "$dry_run" == true ]]; then
  if [[ -e "$agents_file" ]]; then
    info "would back up ${agents_file} and append the DSW persistent storage prompt"
  else
    info "would create ${agents_file} with the DSW persistent storage prompt"
  fi
  exit 0
fi

mkdir -p "$agents_dir"
if [[ -e "$agents_file" ]]; then
  backup_base="${agents_file}.bak.$(date -u +%Y%m%dT%H%M%SZ)"
  backup_file="$backup_base"
  backup_index=1
  while [[ -e "$backup_file" ]]; do
    backup_file="${backup_base}.${backup_index}"
    backup_index=$((backup_index + 1))
  done
  cp -p -- "$agents_file" "$backup_file"
  printf '\n%s\n' "$prompt" >>"$agents_file"
  info "backed up ${agents_file} to ${backup_file} and appended the DSW persistent storage prompt"
else
  printf '%s\n' "$prompt" >"$agents_file"
  info "created ${agents_file} with the DSW persistent storage prompt"
fi
