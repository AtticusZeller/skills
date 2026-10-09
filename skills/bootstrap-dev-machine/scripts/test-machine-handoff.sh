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
[[ -f "${fresh}/.codex/AGENTS.md" && -f "${fresh}/README.md" ]] ||
  fail "Fresh handoff files were not created"
[[ ! -e "${fresh}/AGENTS.md" ]] ||
  fail "Installer created duplicate home-level instructions"
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
cmp -s "${fresh}/.codex/AGENTS.md" "${tmp_dir}/AGENTS.expected.md" ||
  fail "Rendered AGENTS.md does not preserve template fidelity"
cmp -s "${fresh}/README.md" "${tmp_dir}/README.expected.md" ||
  fail "Rendered README.md does not preserve template fidelity"
grep -Fq '`http://127.0.0.1:7890`' "${fresh}/README.md" ||
  fail "Proxy URL was not rendered"
grep -Fq 'Python `3.12`' "${fresh}/README.md" ||
  fail "Python version was not rendered"
grep -Fq 'Node `24`' "${fresh}/README.md" ||
  fail "Node version was not rendered"
if grep -Eq '\{\{[^}]+\}\}' "${fresh}/.codex/AGENTS.md" "${fresh}/README.md"; then
  fail "Rendered handoff contains unresolved placeholders"
fi
pass "fresh machine handoff is rendered deterministically"
printf '@../.codex/AGENTS.md\n' >"${tmp_dir}/claude.expected"
cmp -s "${fresh}/.claude/CLAUDE.md" "${tmp_dir}/claude.expected" ||
  fail "Claude global import was not installed"
cp "${fresh}/.claude/CLAUDE.md" "${tmp_dir}/claude.before"

cp "${fresh}/.codex/AGENTS.md" "${tmp_dir}/agents.before"
cp "${fresh}/README.md" "${tmp_dir}/readme.before"
run_installer "$fresh"
cmp -s "${fresh}/.codex/AGENTS.md" "${tmp_dir}/agents.before" ||
  fail "Second run changed AGENTS.md"
cmp -s "${fresh}/README.md" "${tmp_dir}/readme.before" ||
  fail "Second run changed README.md"
pass "existing handoff files remain unchanged"
cmp -s "${fresh}/.claude/CLAUDE.md" "${tmp_dir}/claude.before" ||
  fail "Second run duplicated the Claude import"
[[ ! -e "${fresh}/AGENTS.md" ]] ||
  fail "Second run created duplicate home-level instructions"

existing="${tmp_dir}/existing home"
mkdir -p "${existing}/.codex" "${existing}/.claude"
printf 'Existing directory rules\n' >"${existing}/AGENTS.md"
cp "${existing}/AGENTS.md" "${tmp_dir}/directory.before"
printf 'Custom Codex rules\n' >"${existing}/.codex/AGENTS.md"
printf 'Custom Claude rules' >"${existing}/.claude/CLAUDE.md"
run_installer "$existing"
printf 'Custom Codex rules\n' >"${tmp_dir}/codex.custom"
printf 'Custom Claude rules\n@../.codex/AGENTS.md\n' >"${tmp_dir}/claude.custom"
cmp -s "${existing}/.codex/AGENTS.md" "${tmp_dir}/codex.custom" ||
  fail "Existing Codex rules were overwritten"
cmp -s "${existing}/.claude/CLAUDE.md" "${tmp_dir}/claude.custom" ||
  fail "Existing Claude rules were not preserved"
cmp -s "${existing}/AGENTS.md" "${tmp_dir}/directory.before" ||
  fail "Existing home-level instructions were changed or removed"
printf '@%s/.codex/AGENTS.md\n' "$existing" >"${existing}/.claude/CLAUDE.md"
cp "${existing}/.claude/CLAUDE.md" "${tmp_dir}/claude.absolute"
run_installer "$existing"
cmp -s "${existing}/.claude/CLAUDE.md" "${tmp_dir}/claude.absolute" ||
  fail "Existing absolute import was duplicated"
printf '@~/.codex/AGENTS.md\n' >"${existing}/.claude/CLAUDE.md"
cp "${existing}/.claude/CLAUDE.md" "${tmp_dir}/claude.tilde"
run_installer "$existing"
cmp -s "${existing}/.claude/CLAUDE.md" "${tmp_dir}/claude.tilde" ||
  fail "Existing home-relative import was duplicated"
pass "shared global instructions preserve custom rules and existing imports"

dry_run="${tmp_dir}/dry-run"
mkdir -p "$dry_run"
run_installer "$dry_run" --dry-run
[[ ! -e "${dry_run}/AGENTS.md" && ! -e "${dry_run}/README.md" ]] ||
  fail "Dry run wrote handoff files"
[[ ! -e "${dry_run}/.codex" && ! -e "${dry_run}/.claude" ]] ||
  fail "Dry run wrote global configuration"
printf 'Custom Claude rules' >"${existing}/.claude/CLAUDE.md"
cp "${existing}/.claude/CLAUDE.md" "${tmp_dir}/claude.dry-run"
run_installer "$existing" --dry-run
cmp -s "${existing}/.claude/CLAUDE.md" "${tmp_dir}/claude.dry-run" ||
  fail "Dry run appended an import to existing Claude rules"
pass "handoff dry run does not write files"

printf '[PASS] machine handoff regression suite completed\n'
