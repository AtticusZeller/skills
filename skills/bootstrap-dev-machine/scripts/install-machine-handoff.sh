#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
asset_dir="${script_dir}/../assets"

target_home="${HOME}"
proxy_url="${PROXY_URL:-http://127.0.0.1:7890}"
python_version="${BOOTSTRAP_PYTHON_VERSION:-3.12}"
node_version="${BOOTSTRAP_NODE_VERSION:-24}"
dry_run=false

usage() {
  cat <<'EOF'
Usage: install-machine-handoff.sh [options]

Install public machine-level AGENTS.md and README.md when absent.

Options:
  --target-home <dir>     Home directory receiving the files (default: $HOME)
  --proxy-url <url>       Public local proxy endpoint
  --python-version <ver>  uv-managed Python version
  --node-version <ver>    nvm-managed Node major version
  --dry-run               Report changes without writing files
  -h, --help              Show this help
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
    --proxy-url)
      require_value "$1" "$#"
      proxy_url="$2"
      shift 2
      ;;
    --python-version)
      require_value "$1" "$#"
      python_version="$2"
      shift 2
      ;;
    --node-version)
      require_value "$1" "$#"
      node_version="$2"
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

validate_input() {
  local label="$1"
  local value="$2"
  [[ -n "$value" ]] || die "${label} must not be empty"
  [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] ||
    die "${label} must be a single line"
  [[ "$value" != *'{{'* && "$value" != *'}}'* ]] ||
    die "${label} must not contain template delimiters"
}

validate_input "Proxy URL" "$proxy_url"
validate_input "Python version" "$python_version"
validate_input "Node version" "$node_version"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
shopt -u patsub_replacement 2>/dev/null || true

render_template() {
  local source="$1"
  local output="$2"
  local line=""

  [[ -f "$source" ]] || die "Missing handoff template: ${source}"
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line//\{\{PROXY_URL\}\}/$proxy_url}"
    line="${line//\{\{PYTHON_VERSION\}\}/$python_version}"
    line="${line//\{\{NODE_VERSION\}\}/$node_version}"
    printf '%s\n' "$line"
  done <"$source" >"$output"

  if grep -Eq '\{\{[^}]+\}\}' "$output"; then
    die "Rendered handoff contains unresolved placeholders: ${source}"
  fi
}

agents_rendered="${tmp_dir}/AGENTS.md"
readme_rendered="${tmp_dir}/README.md"
render_template "${asset_dir}/AGENTS.machine.template.md" "$agents_rendered"
render_template "${asset_dir}/README.machine.template.md" "$readme_rendered"

install_if_absent() {
  local source="$1"
  local destination="$2"

  if [[ -e "$destination" || -L "$destination" ]]; then
    info "skipped existing ${destination}"
    return
  fi
  if [[ "$dry_run" == true ]]; then
    info "would create ${destination}"
    return
  fi
  install -m 0644 "$source" "$destination"
  info "installed ${destination}"
}

install_if_absent "$agents_rendered" "${target_home}/AGENTS.md"
install_if_absent "$readme_rendered" "${target_home}/README.md"

if [[ "$dry_run" == true ]]; then
  info "Dry run completed; no handoff files were changed"
else
  info "Machine handoff installation completed"
fi
