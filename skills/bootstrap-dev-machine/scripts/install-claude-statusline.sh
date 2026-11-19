#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
asset="${script_dir}/../assets/claude-statusline.sh"
target_home="${HOME}"
dry_run=false
print_setting=false

usage() {
  cat <<'EOF'
Usage: install-claude-statusline.sh [--target-home <dir>] [--dry-run] [--print-setting]

Install the Claude Code statusline script when absent and add the statusLine
key to settings.json when that key is missing. Existing scripts and existing
statusLine settings are preserved. Honours CLAUDE_CONFIG_DIR.
--print-setting prints the expected statusLine JSON and changes nothing.
EOF
}

while (($#)); do
  case "$1" in
    --target-home)
      (($# >= 2)) || { echo '--target-home requires a value' >&2; exit 2; }
      target_home="$2"
      shift 2
      ;;
    --dry-run) dry_run=true; shift ;;
    --print-setting) print_setting=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

# --print-setting only reads, so it must work on read-only homes too.
[[ -d "${target_home}" && ( "${print_setting}" == true || ( -w "${target_home}" && -f "${asset}" ) ) ]] || {
  echo "Target home must be a writable directory and the asset must exist" >&2
  exit 1
}
target_home="$(cd "${target_home}" && pwd)"
claude_dir="${CLAUDE_CONFIG_DIR:-${target_home}/.claude}"
script_target="${claude_dir}/statusline-command.sh"
settings="${claude_dir}/settings.json"

# Keep the command portable across usernames when the default directory is used.
if [[ "${claude_dir}" == "${target_home}/.claude" && "${target_home}" == "${HOME}" ]]; then
  command_path='~/.claude/statusline-command.sh'
else
  command_path="$(printf '%q' "${script_target}")"
fi
status_cmd="bash ${command_path}"
jq_status='{type: "command", command: $cmd, refreshInterval: 15}'
if [[ "${print_setting}" == true ]]; then
  jq -n --arg cmd "${status_cmd}" "${jq_status}"
  exit 0
fi

if [[ -e "${script_target}" || -L "${script_target}" ]]; then
  echo "[INFO] Preserved existing ${script_target}"
elif [[ "${dry_run}" == true ]]; then
  echo "[DRY-RUN] Install ${script_target}"
else
  mkdir -p "${claude_dir}"
  install -m 0755 "${asset}" "${script_target}"
  echo "[INFO] Installed ${script_target}"
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[MANUAL] jq is missing; add statusLine {type: command, command: ${status_cmd}, refreshInterval: 15} to ${settings}"
  exit 0
fi

if [[ ! -e "${settings}" ]]; then
  if [[ "${dry_run}" == true ]]; then
    echo "[DRY-RUN] Create ${settings} with statusLine"
  else
    mkdir -p "${claude_dir}"
    jq -n --arg cmd "${status_cmd}" "{statusLine: ${jq_status}}" >"${settings}"
    echo "[INFO] Created ${settings} with statusLine"
  fi
elif ! jq -e 'type == "object"' "${settings}" >/dev/null 2>&1; then
  echo "[MANUAL] ${settings} is not a JSON object; add statusLine by hand"
elif jq -e 'has("statusLine")' "${settings}" >/dev/null; then
  echo "[INFO] Preserved existing statusLine in ${settings}"
elif [[ "${dry_run}" == true ]]; then
  echo "[DRY-RUN] Back up ${settings} and add statusLine"
else
  backup="${settings}.bak.$(date +%Y%m%d%H%M%S).$$"
  cp -p "${settings}" "${backup}"
  tmp="$(mktemp "${settings}.tmp.XXXXXX")"
  jq --arg cmd "${status_cmd}" ". + {statusLine: ${jq_status}}" "${settings}" >"${tmp}"
  chmod --reference="${settings}" "${tmp}" 2>/dev/null || true
  mv "${tmp}" "${settings}"
  echo "[INFO] Added statusLine to ${settings}; backup: ${backup}"
fi
