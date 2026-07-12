#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_dir="$(cd "${script_dir}/.." && pwd)"
init_script="${script_dir}/init-repo-agents.sh"
check_script="${script_dir}/check-repo-agents.sh"
golden="${skill_dir}/tests/golden/AGENTS.md"
managed_begin="<!-- init-repo-agents:managed:begin -->"

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

[[ -f "$golden" ]] || fail "Missing golden file: ${golden}"

fresh="${tmp_dir}/fresh"
mkdir -p "${fresh}/src/example/core" "${fresh}/src/example/io"
run_init "$fresh"
bash "$check_script" --target "$fresh"
cmp -s "${fresh}/AGENTS.md" "${fresh}/CLAUDE.md" ||
  fail "Fresh AGENTS.md and CLAUDE.md differ"
cmp -s "${fresh}/AGENTS.md" "$golden" ||
  fail "Fresh AGENTS.md differs from the golden output"
cmp -s "${fresh}/docs/plan.md" "${skill_dir}/assets/docs/plan.md" ||
  fail "plan.md was not installed verbatim"
cmp -s "${fresh}/cmd.md" "${skill_dir}/assets/cmd.md" ||
  fail "cmd.md was not installed verbatim"
pass "fresh generation matches the golden output and assets"

cp "${fresh}/AGENTS.md" "${tmp_dir}/fresh-agents.before"
cp "${fresh}/CLAUDE.md" "${tmp_dir}/fresh-claude.before"
run_init "$fresh"
cmp -s "${fresh}/AGENTS.md" "${tmp_dir}/fresh-agents.before" ||
  fail "Second run changed AGENTS.md"
cmp -s "${fresh}/CLAUDE.md" "${tmp_dir}/fresh-claude.before" ||
  fail "Second run changed CLAUDE.md"
[[ "$(grep -Fxc "$managed_begin" "${fresh}/AGENTS.md")" -eq 1 ]] ||
  fail "Second run duplicated the managed block"
pass "repeat generation is idempotent"

dry_run="${tmp_dir}/dry-run"
mkdir -p "$dry_run"
run_init "$dry_run" --dry-run
[[ ! -e "${dry_run}/AGENTS.md" && ! -e "${dry_run}/docs" ]] ||
  fail "Dry run changed the target"
pass "dry run does not write target files"

existing="${tmp_dir}/existing"
mkdir -p "$existing"
cat >"${existing}/AGENTS.md" <<'EOF'
# Existing AGENTS Instructions

Keep this AGENTS-only suffix exactly.
EOF
cat >"${existing}/CLAUDE.md" <<'EOF'
# Existing Claude Instructions

Keep this Claude-only suffix exactly.
EOF
run_init "$existing"
bash "$check_script" --target "$existing"
grep -Fq '# Existing AGENTS Instructions' "${existing}/AGENTS.md" ||
  fail "Existing AGENTS.md suffix was lost"
grep -Fq '# Existing Claude Instructions' "${existing}/CLAUDE.md" ||
  fail "Existing CLAUDE.md suffix was lost"
cmp -s "${existing}/AGENTS.md" "${existing}/CLAUDE.md" &&
  fail "Independent existing suffixes were unexpectedly unified"
cp "${existing}/AGENTS.md" "${tmp_dir}/existing-agents.before"
cp "${existing}/CLAUDE.md" "${tmp_dir}/existing-claude.before"
run_init "$existing"
cmp -s "${existing}/AGENTS.md" "${tmp_dir}/existing-agents.before" ||
  fail "Managed-block refresh changed the AGENTS.md suffix"
cmp -s "${existing}/CLAUDE.md" "${tmp_dir}/existing-claude.before" ||
  fail "Managed-block refresh changed the CLAUDE.md suffix"
pass "existing independent suffixes are preserved without duplication"

compressed="${tmp_dir}/compressed"
cp -R "$fresh" "$compressed"
for name in AGENTS.md CLAUDE.md; do
  awk '$0 != "## 2. Alignment · Prerequisite for Coding (Embedded Grill Workflow)"' \
    "${compressed}/${name}" >"${compressed}/${name}.tmp"
  mv "${compressed}/${name}.tmp" "${compressed}/${name}"
done
if bash "$check_script" --target "$compressed" >/dev/null 2>&1; then
  fail "Checker accepted a compressed managed block"
fi
pass "checker rejects compressed template content"

if bash "$init_script" --unknown >/dev/null 2>&1; then
  fail "Unknown option unexpectedly succeeded"
else
  status=$?
  [[ "$status" -eq 2 ]] || fail "Unknown option returned ${status}, expected 2"
fi
pass "invalid arguments return the documented usage error"

printf '[PASS] init-repo-agents regression suite completed\n'
