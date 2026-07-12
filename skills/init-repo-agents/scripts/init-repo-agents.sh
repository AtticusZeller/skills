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
scan_root=""
dry_run=false

managed_begin="<!-- init-repo-agents:managed:begin -->"
managed_end="<!-- init-repo-agents:managed:end -->"
template_meta_end="init-repo-agents:template-meta:end -->"

usage() {
  cat <<'EOF'
Usage: init-repo-agents.sh [options]

Create or update deterministic repository agent scaffolding.

Required:
  --project-name <name>  Project name used in AGENTS.md
  --purpose <text>       One-line project purpose
  --toolchain <text>     Primary language and toolchain

Options:
  --target <dir>         Target repository root (default: current directory)
  --entry-point <path>   Unified command entry point (default: dev.sh)
  --scan-root <path>     Directory whose immediate children are modules
  --dry-run              Report changes without writing files
  -h, --help             Show this help
EOF
}

info() {
  printf '[INFO] %s\n' "$*"
}

error() {
  printf '[ERROR] %s\n' "$*" >&2
}

die() {
  error "$*"
  exit 1
}

require_value() {
  local option="$1"
  local remaining="$2"
  ((remaining >= 2)) || {
    error "${option} requires a value"
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
    --scan-root)
      require_value "$1" "$#"
      scan_root="$2"
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
      error "Unknown option: $1"
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
  [[ "$value" != *'init-repo-agents:'* ]] ||
    die "${label} must not contain managed marker text"
}

validate_input "Project name" "$project_name"
validate_input "Purpose" "$purpose"
validate_input "Toolchain" "$toolchain"
validate_input "Entry point" "$entry_point"

if [[ -n "$scan_root" ]]; then
  if [[ "$scan_root" != /* ]]; then
    scan_root="${target}/${scan_root}"
  fi
  [[ -d "$scan_root" ]] || die "Scan root is not a directory: ${scan_root}"
  scan_root="$(cd "$scan_root" && pwd)"
  [[ "$scan_root" == "$target" || "$scan_root" == "$target/"* ]] ||
    die "Scan root must be inside the target repository"
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
rendered="${tmp_dir}/AGENTS.rendered.md"
module_index="${tmp_dir}/module-index.md"

is_module_dir() {
  local name="$1"
  case "$name" in
    .*|__pycache__|node_modules|vendor) return 1 ;;
    *) return 0 ;;
  esac
}

immediate_dirs() {
  local root="$1"
  local dir=""
  local name=""
  shopt -s nullglob
  for dir in "$root"/*; do
    [[ -d "$dir" ]] || continue
    name="${dir##*/}"
    is_module_dir "$name" || continue
    printf '%s\0' "$dir"
  done
  shopt -u nullglob
}

module_dirs=()
if [[ -n "$scan_root" ]]; then
  while IFS= read -r -d '' dir; do
    module_dirs+=("$dir")
  done < <(immediate_dirs "$scan_root" | sort -z)
elif [[ -d "${target}/src" ]]; then
  first_level=()
  while IFS= read -r -d '' dir; do
    first_level+=("$dir")
  done < <(immediate_dirs "${target}/src" | sort -z)

  if ((${#first_level[@]} == 1)); then
    while IFS= read -r -d '' dir; do
      module_dirs+=("$dir")
    done < <(immediate_dirs "${first_level[0]}" | sort -z)
  fi
  if ((${#module_dirs[@]} == 0)); then
    module_dirs=("${first_level[@]}")
  fi
fi

if ((${#module_dirs[@]} == 0)); then
  printf '%s\n' \
    '- No modules were discovered during the shallow initialization scan.' \
    >"$module_index"
else
  for dir in "${module_dirs[@]}"; do
    name="${dir##*/}"
    slug="$(
      printf '%s' "$name" |
        tr '[:upper:]_' '[:lower:]-' |
        tr -cs '[:alnum:]-' '-'
    )"
    slug="${slug#-}"
    slug="${slug%-}"
    [[ -n "$slug" ]] || slug="module"
    relative="${dir#"$target"/}"
    printf -- '- [[docs/%s.md]] — %s module (`%s/`)\n' \
      "$slug" "$name" "$relative" >>"$module_index"
  done
fi

shopt -u patsub_replacement 2>/dev/null || true
inside_managed=false
found_managed_end=false
while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" == "$managed_begin" ]]; then
    inside_managed=true
  fi
  [[ "$inside_managed" == true ]] || continue

  if [[ "$line" == '{{MODULE_INDEX}}' ]]; then
    while IFS= read -r module_line || [[ -n "$module_line" ]]; do
      printf '%s\n' "$module_line"
    done <"$module_index"
  else
    line="${line//\{\{PROJECT_NAME\}\}/$project_name}"
    line="${line//\{\{ONE_LINE_PURPOSE\}\}/$purpose}"
    line="${line//\{\{PRIMARY_TOOLCHAIN\}\}/$toolchain}"
    line="${line//\{\{ENTRY_POINT\}\}/$entry_point}"
    printf '%s\n' "$line"
  fi

  if [[ "$line" == "$managed_end" ]]; then
    found_managed_end=true
    break
  fi
done <"$template" >"$rendered"

[[ "$found_managed_end" == true ]] ||
  die "Template does not contain a complete managed block"
if grep -Eq '\{\{[^}]+\}\}' "$rendered"; then
  die "Rendered template contains unresolved placeholders"
fi
[[ "$(sed -n '1p' "$rendered")" == "$managed_begin" ]] ||
  die "Rendered template has an invalid managed block start"
[[ "$(sed -n '$p' "$rendered")" == "$managed_end" ]] ||
  die "Rendered template has an invalid managed block end"
grep -Fq "$template_meta_end" "$template" ||
  die "Template metadata boundary is missing"

prepare_managed_file() {
  local existing="$1"
  local output="$2"
  local begin_count=0
  local end_count=0
  local begin_line=0
  local end_line=0

  if [[ ! -e "$existing" ]]; then
    cp "$rendered" "$output"
    return
  fi
  [[ ! -L "$existing" ]] || die "Refusing to replace symlink: ${existing}"
  [[ -f "$existing" ]] || die "Expected a regular file: ${existing}"

  begin_count="$(awk -v marker="$managed_begin" '$0 == marker { count++ } END { print count + 0 }' "$existing")"
  end_count="$(awk -v marker="$managed_end" '$0 == marker { count++ } END { print count + 0 }' "$existing")"

  if ((begin_count == 0 && end_count == 0)); then
    {
      cat "$rendered"
      printf '\n<!-- init-repo-agents:preserved-content-below -->\n\n'
      cat "$existing"
    } >"$output"
    return
  fi

  ((begin_count == 1 && end_count == 1)) ||
    die "Malformed or duplicated managed block in ${existing}"
  begin_line="$(awk -v marker="$managed_begin" '$0 == marker { print NR; exit }' "$existing")"
  end_line="$(awk -v marker="$managed_end" '$0 == marker { print NR; exit }' "$existing")"
  ((begin_line == 1 && end_line >= begin_line)) ||
    die "Managed block must be at the top of ${existing}"

  cp "$rendered" "$output"
  tail -n "+$((end_line + 1))" "$existing" >>"$output"
}

agents_output="${tmp_dir}/AGENTS.md"
claude_output="${tmp_dir}/CLAUDE.md"
prepare_managed_file "${target}/AGENTS.md" "$agents_output"
prepare_managed_file "${target}/CLAUDE.md" "$claude_output"

for required_asset in \
  "${asset_dir}/docs/plan.md" \
  "${asset_dir}/docs/log.md" \
  "${asset_dir}/docs/bug.md" \
  "${asset_dir}/cmd.md"; do
  [[ -f "$required_asset" ]] || die "Missing scaffold asset: ${required_asset}"
done

report_managed_action() {
  local source="$1"
  local destination="$2"
  if [[ ! -e "$destination" ]]; then
    info "would create ${destination}"
  elif cmp -s "$source" "$destination"; then
    info "unchanged ${destination}"
  else
    info "would update managed block in ${destination}"
  fi
}

report_asset_action() {
  local destination="$1"
  if [[ -e "$destination" ]]; then
    info "skipped existing ${destination}"
  else
    info "would create ${destination}"
  fi
}

if [[ "$dry_run" == true ]]; then
  report_managed_action "$agents_output" "${target}/AGENTS.md"
  report_managed_action "$claude_output" "${target}/CLAUDE.md"
  report_asset_action "${target}/docs/plan.md"
  report_asset_action "${target}/docs/log.md"
  report_asset_action "${target}/docs/bug.md"
  report_asset_action "${target}/cmd.md"
  info "Dry run completed; no target files were changed"
  exit 0
fi

mkdir -p "${target}/docs"

install_managed_file() {
  local source="$1"
  local destination="$2"
  if [[ -e "$destination" ]] && cmp -s "$source" "$destination"; then
    info "unchanged ${destination}"
    return
  fi
  install -m 0644 "$source" "$destination"
  info "installed ${destination}"
}

install_asset_if_absent() {
  local source="$1"
  local destination="$2"
  if [[ -e "$destination" ]]; then
    [[ ! -L "$destination" ]] || die "Refusing existing symlink: ${destination}"
    info "skipped existing ${destination}"
    return
  fi
  install -m 0644 "$source" "$destination"
  info "installed ${destination}"
}

install_managed_file "$agents_output" "${target}/AGENTS.md"
install_managed_file "$claude_output" "${target}/CLAUDE.md"
install_asset_if_absent "${asset_dir}/docs/plan.md" "${target}/docs/plan.md"
install_asset_if_absent "${asset_dir}/docs/log.md" "${target}/docs/log.md"
install_asset_if_absent "${asset_dir}/docs/bug.md" "${target}/docs/bug.md"
install_asset_if_absent "${asset_dir}/cmd.md" "${target}/cmd.md"

info "Repository agent scaffolding completed"
