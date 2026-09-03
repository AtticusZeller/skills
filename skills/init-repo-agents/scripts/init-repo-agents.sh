#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_dir="$(cd "${script_dir}/.." && pwd)"
template="${skill_dir}/references/AGENTS.template.md"
asset_dir="${skill_dir}/assets"

target="."
project_name=""
purpose=""
toolchain=""
entry_point="dev.sh"
dry_run=false

usage() {
  cat <<'EOF'
Usage: init-repo-agents.sh [options]

Create deterministic repository agent scaffolding without replacing custom files.

Required:
  --project-name <name>  Project name used in AGENTS.md
  --purpose <text>       One-line project purpose
  --toolchain <text>     Primary language and toolchain

Options:
  --target <dir>         Target repository root (default: current directory)
  --entry-point <path>   Unified command entry point (default: dev.sh)
  --dry-run              Preview actions without writing files
  -h, --help             Show this help
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
    --target)
      require_value "$1" "$#"
      target="$2"
      shift 2
      ;;
    --project-name)
      require_value "$1" "$#"
      project_name="$2"
      shift 2
      ;;
    --purpose)
      require_value "$1" "$#"
      purpose="$2"
      shift 2
      ;;
    --toolchain)
      require_value "$1" "$#"
      toolchain="$2"
      shift 2
      ;;
    --entry-point)
      require_value "$1" "$#"
      entry_point="$2"
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

[[ -d "$target" ]] || die "Target is not a directory: ${target}"
target="$(cd "$target" && pwd)"
[[ -w "$target" ]] || die "Target directory is not writable: ${target}"
[[ -f "$template" ]] || die "Missing template: ${template}"

validate_input() {
  local label="$1"
  local value="$2"
  [[ -n "$value" ]] || die "${label} must not be empty"
  [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] ||
    die "${label} must be a single line"
  [[ "$value" != *'{{'* && "$value" != *'}}'* ]] ||
    die "${label} must not contain template delimiters"
}

validate_input "Project name" "$project_name"
validate_input "Purpose" "$purpose"
validate_input "Toolchain" "$toolchain"
validate_input "Entry point" "$entry_point"

required_assets=(
  "docs/AGENTS.md"
  "docs/workspace/plan.md"
  "docs/workspace/log.md"
  "docs/workspace/overview.md"
)
for relative in "${required_assets[@]}"; do
  [[ -f "${asset_dir}/${relative}" ]] || die "Missing scaffold asset: ${relative}"
done

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
rendered_agents="${tmp_dir}/AGENTS.md"
rendered_claude="${tmp_dir}/CLAUDE.md"

shopt -u patsub_replacement 2>/dev/null || true
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line//\{\{PROJECT_NAME\}\}/$project_name}"
  line="${line//\{\{ONE_LINE_PURPOSE\}\}/$purpose}"
  line="${line//\{\{PRIMARY_TOOLCHAIN\}\}/$toolchain}"
  line="${line//\{\{ENTRY_POINT\}\}/$entry_point}"
  printf '%s\n' "$line"
done <"$template" >"$rendered_agents"
printf '@AGENTS.md\n' >"$rendered_claude"

if grep -Eq '\{\{[^}]+\}\}' "$rendered_agents"; then
  die "Rendered AGENTS.md contains unresolved placeholders"
fi

preflight_rule_file() {
  local expected="$1"
  local destination="$2"
  if [[ -L "$destination" || (-e "$destination" && ! -f "$destination") ]]; then
    die "Refusing non-regular rule path: ${destination}"
  fi
  if [[ -f "$destination" && ! "$expected" -ef "$destination" ]] &&
    ! cmp -s "$expected" "$destination"; then
    die "Refusing to replace custom rule file: ${destination}"
  fi
}

preflight_asset() {
  local destination="$1"
  if [[ -L "$destination" || (-e "$destination" && ! -f "$destination") ]]; then
    die "Refusing non-regular documentation path: ${destination}"
  fi
}

preflight_rule_file "$rendered_agents" "${target}/AGENTS.md"
preflight_rule_file "$rendered_claude" "${target}/CLAUDE.md"
for relative in "${required_assets[@]}"; do
  preflight_asset "${target}/${relative}"
done

report_action() {
  local expected="$1"
  local destination="$2"
  if [[ ! -e "$destination" ]]; then
    info "would create ${destination}"
  elif cmp -s "$expected" "$destination"; then
    info "unchanged ${destination}"
  else
    info "skipped existing ${destination}"
  fi
}

if [[ "$dry_run" == true ]]; then
  report_action "$rendered_agents" "${target}/AGENTS.md"
  report_action "$rendered_claude" "${target}/CLAUDE.md"
  for relative in "${required_assets[@]}"; do
    report_action "${asset_dir}/${relative}" "${target}/${relative}"
  done
  info "Dry run completed; no target files were changed"
  exit 0
fi

install_if_absent() {
  local source="$1"
  local destination="$2"
  if [[ -e "$destination" ]]; then
    info "unchanged ${destination}"
    return
  fi
  mkdir -p "$(dirname "$destination")"
  install -m 0644 "$source" "$destination"
  info "installed ${destination}"
}

install_if_absent "$rendered_agents" "${target}/AGENTS.md"
install_if_absent "$rendered_claude" "${target}/CLAUDE.md"
for relative in "${required_assets[@]}"; do
  install_if_absent "${asset_dir}/${relative}" "${target}/${relative}"
done

info "Repository agent scaffolding completed"
