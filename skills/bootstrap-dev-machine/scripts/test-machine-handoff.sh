#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
installer="${script_dir}/install-machine-handoff.sh"
asset_dir="${script_dir}/../assets"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

pass() {
  printf '[PASS] %s\n' "$*"
}

run_installer() {
  local target="$1"
  shift
  bash "$installer" \
    --target-home "$target" \
    --proxy-url "http://127.0.0.1:7890" \
    --python-version "3.12" \
    --node-version "24" \
    "$@"
}

fresh="${tmp_dir}/fresh"
mkdir -p "$fresh"
run_installer "$fresh"
[[ -f "${fresh}/AGENTS.md" && -f "${fresh}/README.md" ]] ||
  fail "Fresh handoff files were not created"
sed \
  -e 's|{{PROXY_URL}}|http://127.0.0.1:7890|g' \
  -e 's|{{PYTHON_VERSION}}|3.12|g' \
  -e 's|{{NODE_VERSION}}|24|g' \
  "${asset_dir}/AGENTS.machine.template.md" >"${tmp_dir}/AGENTS.expected.md"
sed \
  -e 's|{{PROXY_URL}}|http://127.0.0.1:7890|g' \
  -e 's|{{PYTHON_VERSION}}|3.12|g' \
  -e 's|{{NODE_VERSION}}|24|g' \
  "${asset_dir}/README.machine.template.md" >"${tmp_dir}/README.expected.md"
cmp -s "${fresh}/AGENTS.md" "${tmp_dir}/AGENTS.expected.md" ||
  fail "Rendered AGENTS.md does not preserve template fidelity"
cmp -s "${fresh}/README.md" "${tmp_dir}/README.expected.md" ||
  fail "Rendered README.md does not preserve template fidelity"
grep -Fq '`http://127.0.0.1:7890`' "${fresh}/AGENTS.md" ||
  fail "Proxy URL was not rendered"
grep -Fq 'Python `3.12`' "${fresh}/README.md" ||
  fail "Python version was not rendered"
grep -Fq 'Node `24`' "${fresh}/README.md" ||
  fail "Node version was not rendered"
if grep -Eq '\{\{[^}]+\}\}' "${fresh}/AGENTS.md" "${fresh}/README.md"; then
  fail "Rendered handoff contains unresolved placeholders"
fi
pass "fresh machine handoff is rendered deterministically"

cp "${fresh}/AGENTS.md" "${tmp_dir}/agents.before"
cp "${fresh}/README.md" "${tmp_dir}/readme.before"
run_installer "$fresh"
cmp -s "${fresh}/AGENTS.md" "${tmp_dir}/agents.before" ||
  fail "Second run changed AGENTS.md"
cmp -s "${fresh}/README.md" "${tmp_dir}/readme.before" ||
  fail "Second run changed README.md"
pass "existing handoff files remain unchanged"

dry_run="${tmp_dir}/dry-run"
mkdir -p "$dry_run"
run_installer "$dry_run" --dry-run
[[ ! -e "${dry_run}/AGENTS.md" && ! -e "${dry_run}/README.md" ]] ||
  fail "Dry run wrote handoff files"
pass "handoff dry run does not write files"

printf '[PASS] machine handoff regression suite completed\n'
