#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
script="$script_dir/dsw-persist"
asset="$script_dir/../assets/env.sh.template"
agents_asset="$script_dir/../assets/codex-agents-block.md"
tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT

fail() {
    printf '[FAIL] %s\n' "$*" >&2
    exit 1
}

pass() {
    printf '[PASS] %s\n' "$*"
}

bash -n "$script"
bash -n "$asset"
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck "$script" "$asset" "$0"
    pass "shellcheck"
else
    pass "shellcheck skipped (not installed)"
fi
pass "bash syntax"

home="$tmp_dir/home"
mount_dir="$tmp_dir/plain-directory"
mkdir -p "$home/.codex" "$mount_dir"
printf '%s\n' 'export KEEP_ME=yes' >"$home/.bashrc"
printf '%s\n' '# keep zsh content' >"$home/.zshrc"
printf '%s\n' '# Keep existing Codex rule' >"$home/.codex/AGENTS.md"

mountpoint() {
    [[ "${FAKE_MOUNT_OK:-0}" == "1" ]]
}
export -f mountpoint

set +e
HOME="$home" \
    CODEX_HOME="$home/.codex" \
    DSW_PERSIST_TESTING=1 \
    DSW_PERSIST_TEST_MOUNT_PATH="$mount_dir" \
    FAKE_MOUNT_OK=0 \
    bash "$script" doctor >"$tmp_dir/doctor-negative.log" 2>&1
doctor_rc=$?
HOME="$home" \
    CODEX_HOME="$home/.codex" \
    DSW_PERSIST_TESTING=1 \
    DSW_PERSIST_TEST_MOUNT_PATH="$mount_dir" \
    FAKE_MOUNT_OK=0 \
    bash "$script" init >"$tmp_dir/init-negative.log" 2>&1
init_rc=$?
set -e

[[ "$doctor_rc" -ne 0 && "$init_rc" -ne 0 ]] ||
    fail "doctor and init must reject a plain directory"
[[ ! -e "$mount_dir/atticux" ]] ||
    fail "rejected init created the personal directory"
grep -Fq '当前不是已确认的持久化挂载点' "$tmp_dir/doctor-negative.log" ||
    fail "doctor did not explain the unconfirmed mount"
pass "plain directory is rejected without writes"

run_init() {
    HOME="$home" \
        CODEX_HOME="$home/.codex" \
        DSW_PERSIST_TESTING=1 \
        DSW_PERSIST_TEST_MOUNT_PATH="$mount_dir" \
        FAKE_MOUNT_OK=1 \
        bash "$script" init
}

run_init >"$tmp_dir/init-first.log"
cp "$home/.codex/AGENTS.md" "$tmp_dir/agents-after-first.md"
run_init >"$tmp_dir/init-second.log"
cmp -s "$home/.codex/AGENTS.md" "$tmp_dir/agents-after-first.md" ||
    fail "second init changed the Codex AGENTS file"

[[ "$(grep -Fxc '# >>> aliyun-dsw-persistence >>>' "$home/.bashrc")" == "1" ]] ||
    fail "bash managed block was duplicated"
[[ "$(grep -Fxc '# >>> aliyun-dsw-persistence >>>' "$home/.zshrc")" == "1" ]] ||
    fail "zsh managed block was duplicated"
grep -Fqx 'export KEEP_ME=yes' "$home/.bashrc" ||
    fail "existing bashrc content was lost"
grep -Fqx '# keep zsh content' "$home/.zshrc" ||
    fail "existing zshrc content was lost"
compgen -G "$home/.bashrc.bak.*" >/dev/null ||
    fail "bashrc backup was not created"
compgen -G "$home/.zshrc.bak.*" >/dev/null ||
    fail "zshrc backup was not created"
pass "init is idempotent and preserves shell configuration"

[[ "$(grep -Fxc '<!-- >>> aliyun-dsw-persistence >>> -->' "$home/.codex/AGENTS.md")" == "1" ]] ||
    fail "Codex AGENTS managed block was duplicated"
grep -Fqx '# Keep existing Codex rule' "$home/.codex/AGENTS.md" ||
    fail "existing Codex AGENTS content was lost"
compgen -G "$home/.codex/AGENTS.md.bak.*" >/dev/null ||
    fail "Codex AGENTS backup was not created"
awk '
    $0 == "<!-- >>> aliyun-dsw-persistence >>> -->" { capture = 1 }
    capture { print }
    capture && $0 == "<!-- <<< aliyun-dsw-persistence <<< -->" { exit }
' "$home/.codex/AGENTS.md" >"$tmp_dir/agents-block.actual.md"
cmp -s "$tmp_dir/agents-block.actual.md" "$agents_asset" ||
    fail "Codex AGENTS block does not match the bundled asset"
sed -i 's/Before downloading large models/Before downloading stale models/' \
    "$home/.codex/AGENTS.md"
run_init >"$tmp_dir/init-repair.log"
awk '
    $0 == "<!-- >>> aliyun-dsw-persistence >>> -->" { capture = 1 }
    capture { print }
    capture && $0 == "<!-- <<< aliyun-dsw-persistence <<< -->" { exit }
' "$home/.codex/AGENTS.md" >"$tmp_dir/agents-block.repaired.md"
cmp -s "$tmp_dir/agents-block.repaired.md" "$agents_asset" ||
    fail "init did not repair an outdated Codex AGENTS block"
pass "Codex AGENTS block is preserved, idempotent, and repairable"

for path in \
    models \
    datasets \
    checkpoints \
    outputs \
    archives \
    cache/huggingface \
    cache/modelscope \
    cache/torch \
    cache/pip \
    cache/uv \
    cache/downloads; do
    [[ -d "$mount_dir/atticux/$path" ]] ||
        fail "missing initialized directory: $path"
done
[[ ! -e "$mount_dir/atticux/code" && ! -e "$mount_dir/atticux/envs" ]] ||
    fail "init created a forbidden code or envs directory"
pass "directory layout"

env_file="$home/.config/dsw-persistence/env.sh"
expected_env="$tmp_dir/env.expected.sh"
sed \
    -e "s|{{MOUNT_PATH}}|$mount_dir|g" \
    -e "s|{{PERSIST_ROOT}}|$mount_dir/atticux|g" \
    "$asset" >"$expected_env"
cmp -s "$env_file" "$expected_env" ||
    fail "rendered env.sh does not match the bundled template"
bash -n "$env_file"
if grep -Eq '^export (HOME|PYTHONPATH|CUDA_HOME|LD_LIBRARY_PATH|CONDA_PKGS_DIRS|XDG_CACHE_HOME)=' "$env_file"; then
    fail "env.sh configures a forbidden variable"
fi
HOME="$home" FAKE_MOUNT_OK=1 bash --noprofile --norc -c \
    '. "$HOME/.config/dsw-persistence/env.sh"; [[ "$DSW_PERSIST_ROOT" == "'"$mount_dir"'/atticux" ]]' ||
    fail "env.sh did not load for a confirmed mount"
HOME="$home" FAKE_MOUNT_OK=0 bash --noprofile --norc -c \
    'unset DSW_PERSIST_ROOT; . "$HOME/.config/dsw-persistence/env.sh"; [[ -z "${DSW_PERSIST_ROOT:-}" ]]' ||
    fail "env.sh loaded persistent paths for an unconfirmed mount"
pass "template fidelity and mount guard"

install_home="$tmp_dir/install-home"
mkdir -p "$install_home"
HOME="$install_home" bash "$script" install-command >"$tmp_dir/install-first.log"
HOME="$install_home" bash "$script" install-command >"$tmp_dir/install-second.log"
[[ -L "$install_home/.local/bin/dsw-persist" ]] ||
    fail "install-command did not create a symlink"
[[ "$(readlink -f "$install_home/.local/bin/dsw-persist")" == "$(readlink -f "$script")" ]] ||
    fail "installed command points to the wrong script"
pass "command installation is idempotent"

unset -f mountpoint
if command -v zsh >/dev/null 2>&1; then
    zsh -n "$env_file"
    env -i HOME="$home" PATH="$PATH" zsh -f -c \
        'unset DSW_PERSIST_ROOT; source "$HOME/.config/dsw-persistence/env.sh"; [[ -z "${DSW_PERSIST_ROOT:-}" ]]' ||
        fail "zsh mount guard failed"
    pass "zsh syntax and mount guard"
else
    pass "zsh checks skipped (not installed)"
fi

printf '[PASS] aliyun-dsw-persistence regression suite completed\n'
