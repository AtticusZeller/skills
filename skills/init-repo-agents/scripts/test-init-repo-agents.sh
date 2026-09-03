#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_dir="$(cd "${script_dir}/.." && pwd)"
init_script="${script_dir}/init-repo-agents.sh"
check_script="${script_dir}/check-repo-agents.sh"
template="${skill_dir}/references/AGENTS.template.md"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

pass() {
  printf '[PASS] %s\n' "$*"
}

run_init() {
  local target="$1"
  shift
  bash "$init_script" \
    --target "$target" \
    --project-name "Example Project" \
    --purpose "Exercises deterministic repository scaffolding." \
    --toolchain "Python 3.12 + uv/ruff/ty" \
    --entry-point "dev.sh" \
    "$@"
}

fresh="${tmp_dir}/fresh"
mkdir -p "$fresh"
run_init "$fresh"
bash "$check_script" --target "$fresh"
sed \
  -e 's|{{PROJECT_NAME}}|Example Project|g' \
  -e 's|{{ONE_LINE_PURPOSE}}|Exercises deterministic repository scaffolding.|g' \
  -e 's|{{PRIMARY_TOOLCHAIN}}|Python 3.12 + uv/ruff/ty|g' \
  -e 's|{{ENTRY_POINT}}|dev.sh|g' \
  "$template" >"${tmp_dir}/expected-agents.md"
cmp -s "${fresh}/AGENTS.md" "${tmp_dir}/expected-agents.md" ||
  fail "Fresh AGENTS.md differs from the rendered template"
[[ "$(cat "${fresh}/CLAUDE.md")" == '@AGENTS.md' ]] ||
  fail "CLAUDE.md does not import AGENTS.md"
for relative in \
  docs/AGENTS.md \
  docs/workspace/plan.md \
  docs/workspace/log.md \
  docs/workspace/overview.md; do
  cmp -s "${fresh}/${relative}" "${skill_dir}/assets/${relative}" ||
    fail "${relative} was not installed verbatim"
done
for retired in cmd.md docs/bug.md docs/cognitive-debt.md docs/plan.md docs/log.md; do
  [[ ! -e "${fresh}/${retired}" ]] || fail "Retired asset was created: ${retired}"
done
pass "fresh generation matches the golden output and current assets"

cp "${fresh}/AGENTS.md" "${tmp_dir}/agents.before"
cp "${fresh}/CLAUDE.md" "${tmp_dir}/claude.before"
run_init "$fresh"
cmp -s "${fresh}/AGENTS.md" "${tmp_dir}/agents.before" ||
  fail "Second run changed AGENTS.md"
cmp -s "${fresh}/CLAUDE.md" "${tmp_dir}/claude.before" ||
  fail "Second run changed CLAUDE.md"
pass "repeat generation is idempotent"

dry_run="${tmp_dir}/dry-run"
mkdir -p "$dry_run"
run_init "$dry_run" --dry-run
[[ ! -e "${dry_run}/AGENTS.md" && ! -e "${dry_run}/docs" ]] ||
  fail "Dry run changed the target"
pass "dry run does not write target files"

custom_agents="${tmp_dir}/custom-agents"
mkdir -p "$custom_agents"
printf '# Custom Rules\n\nKeep this file.\n' >"${custom_agents}/AGENTS.md"
cp "${custom_agents}/AGENTS.md" "${tmp_dir}/custom-agents.before"
if run_init "$custom_agents" >/dev/null 2>&1; then
  fail "Initializer replaced or accepted a custom AGENTS.md"
fi
cmp -s "${custom_agents}/AGENTS.md" "${tmp_dir}/custom-agents.before" ||
  fail "Custom AGENTS.md changed after refusal"
[[ ! -e "${custom_agents}/CLAUDE.md" && ! -e "${custom_agents}/docs" ]] ||
  fail "Refused initialization still wrote scaffold files"
pass "custom AGENTS.md is preserved and blocks generation"

custom_claude="${tmp_dir}/custom-claude"
mkdir -p "$custom_claude"
printf '# Custom Claude Rules\n' >"${custom_claude}/CLAUDE.md"
if run_init "$custom_claude" >/dev/null 2>&1; then
  fail "Initializer replaced or accepted a custom CLAUDE.md"
fi
[[ ! -e "${custom_claude}/AGENTS.md" ]] ||
  fail "Refused CLAUDE.md initialization still wrote AGENTS.md"
pass "custom CLAUDE.md is preserved and blocks generation"

preserved_docs="${tmp_dir}/preserved-docs"
cp -R "$fresh" "$preserved_docs"
printf '\n人工维护的稳定结论。\n' >>"${preserved_docs}/docs/workspace/overview.md"
cp "${preserved_docs}/docs/workspace/overview.md" "${tmp_dir}/overview.before"
run_init "$preserved_docs"
cmp -s "${preserved_docs}/docs/workspace/overview.md" "${tmp_dir}/overview.before" ||
  fail "Existing documentation was overwritten"
pass "existing documentation assets are preserved"

extended="${tmp_dir}/extended"
cp -R "$fresh" "$extended"
printf '\n## Repository-Specific Rules\n\nKeep generated data out of Git.\n' \
  >>"${extended}/AGENTS.md"
bash "$check_script" --target "$extended" >/dev/null
pass "checker accepts confirmed repository-specific additions"

missing_rule="${tmp_dir}/missing-rule"
cp -R "$fresh" "$missing_rule"
sed -i '/^Do not add unrequested features, abstractions, dependencies, refactors, or cleanup\.$/d' \
  "${missing_rule}/AGENTS.md"
if bash "$check_script" --target "$missing_rule" >/dev/null 2>&1; then
  fail "Checker accepted AGENTS.md without the scope-discipline rule"
fi
pass "checker rejects missing required behavior"

wrong_pointer="${tmp_dir}/wrong-pointer"
cp -R "$fresh" "$wrong_pointer"
printf '# Duplicate rules\n' >"${wrong_pointer}/CLAUDE.md"
if bash "$check_script" --target "$wrong_pointer" >/dev/null 2>&1; then
  fail "Checker accepted a divergent CLAUDE.md"
fi
pass "checker rejects a divergent CLAUDE.md"

if bash "$init_script" --unknown >/dev/null 2>&1; then
  fail "Unknown option unexpectedly succeeded"
else
  status=$?
  [[ "$status" -eq 2 ]] || fail "Unknown option returned ${status}, expected 2"
fi
pass "invalid arguments return the documented usage error"

printf '[PASS] init-repo-agents regression suite completed\n'
