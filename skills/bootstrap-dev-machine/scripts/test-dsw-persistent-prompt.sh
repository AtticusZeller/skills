#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
installer="${script_dir}/install-dsw-persistent-prompt.sh"
prompt_file="${script_dir}/../assets/dsw-persistent-prompt.md"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

pass() {
  printf '[PASS] %s\n' "$*"
}

home="${tmp_dir}/home"
mkdir -p "${home}/.codex"
agents_file="${home}/.codex/AGENTS.md"
printf '%s\n' '# Preserve this existing rule' >"$agents_file"
prompt="$(<"$prompt_file")"

bash "$installer" --target-home "$home"
grep -Fqx '# Preserve this existing rule' "$agents_file" ||
  fail "existing AGENTS.md content was lost"
[[ "$(grep -Fxc -- "$prompt" "$agents_file")" == "1" ]] ||
  fail "DSW prompt was not appended exactly once"
compgen -G "${agents_file}.bak.*" >/dev/null ||
  fail "AGENTS.md backup was not created"
cp "$agents_file" "${tmp_dir}/agents.after-first"

bash "$installer" --target-home "$home"
cmp -s "$agents_file" "${tmp_dir}/agents.after-first" ||
  fail "second installation changed AGENTS.md"
[[ "$(compgen -G "${agents_file}.bak.*" | wc -l)" == "1" ]] ||
  fail "second installation created an unnecessary backup"
pass "DSW prompt installation is idempotent and preserves existing rules"

dry_home="${tmp_dir}/dry-home"
mkdir -p "$dry_home"
bash "$installer" --target-home "$dry_home" --dry-run
[[ ! -e "${dry_home}/.codex/AGENTS.md" ]] ||
  fail "dry run wrote AGENTS.md"
pass "DSW prompt dry run does not write files"

printf '[PASS] DSW persistent prompt regression suite completed\n'
