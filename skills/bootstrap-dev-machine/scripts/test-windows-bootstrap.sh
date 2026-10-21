#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
asset_dir="${script_dir}/../assets"
scripts=("${script_dir}/bootstrap-dev-machine.ps1" "${script_dir}/check-dev-machine.ps1")

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

pass() {
  printf '[PASS] %s\n' "$*"
}

for file in "${scripts[@]}"; do
  [[ -f "$file" ]] || fail "Missing script: $file"
  # Windows PowerShell 5.1 misreads BOM-less UTF-8, so scripts stay ASCII.
  if LC_ALL=C grep -q '[^ -~[:space:]]' "$file"; then
    fail "PowerShell script contains non-ASCII bytes: $file"
  fi
done
pass "PowerShell scripts are ASCII-only"

apps="${asset_dir}/winget-apps.txt"
[[ -f "$apps" ]] || fail "Missing winget application list"
app_count=0
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%$'\r'}"
  [[ -z "$line" || "$line" == \#* ]] && continue
  [[ "$line" =~ ^[A-Za-z0-9][A-Za-z0-9.+_-]*\.[A-Za-z0-9.+_-]+$ ]] ||
    fail "Invalid winget package ID: $line"
  app_count=$((app_count + 1))
done <"$apps"
((app_count > 0)) || fail "winget application list is empty"
pass "winget application list contains ${app_count} valid ID(s)"

if grep -Eqi 'miniforge|mamba' "${scripts[0]}"; then
  fail "Windows installer must not install Conda"
fi
pass "Windows installer does not install Conda"

powershell=""
for candidate in pwsh powershell.exe powershell; do
  if command -v "$candidate" >/dev/null 2>&1; then
    powershell="$candidate"
    break
  fi
done
if [[ -z "$powershell" ]]; then
  printf '[SKIP] PowerShell unavailable; parse and help checks skipped\n'
  printf '[PASS] Windows bootstrap regression suite completed\n'
  exit 0
fi

to_native_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1"
  else
    printf '%s\n' "$1"
  fi
}

for file in "${scripts[@]}"; do
  native="$(to_native_path "$file")"
  errors="$("$powershell" -NoProfile -NonInteractive -Command \
    "\$errors = \$null; \$null = [System.Management.Automation.Language.Parser]::ParseFile('${native}', [ref]\$null, [ref]\$errors); \$errors | ForEach-Object { \$_.ToString() }")"
  [[ -z "$errors" ]] || fail "PowerShell parse errors in ${file}: ${errors}"
done
pass "PowerShell scripts parse without errors"

bootstrap="$(to_native_path "${scripts[0]}")"
help_output="$("$powershell" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$bootstrap" -Help)"
grep -Fq -- '-SkipApps' <<<"$help_output" || fail "Help output does not list -SkipApps"
if grep -Fq -- '-SkipConda' <<<"$help_output"; then
  fail "Help output still offers Conda options"
fi
pass "installer help documents the Windows options"

if [[ "$(uname -s)" != MINGW* && "$(uname -s)" != MSYS* && "$(uname -s)" != CYGWIN* ]]; then
  if "$powershell" -NoProfile -NonInteractive -File "$bootstrap" >/dev/null 2>&1; then
    fail "Windows installer ran on a non-Windows host"
  fi
  pass "Windows installer refuses non-Windows hosts"
fi

printf '[PASS] Windows bootstrap regression suite completed\n'
