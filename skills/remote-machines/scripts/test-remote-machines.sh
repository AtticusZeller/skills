#!/usr/bin/env bash
# Regression test for registry merging and command composition. Uses a fixture registry and
# --dry-run only, so it never opens an SSH connection.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export REMOTE_MACHINES_DIR="$tmp"
unset UV_DEFAULT_INDEX PIP_INDEX_URL

cat >"$tmp/_defaults.yaml" <<'EOF'
owner: tester
history_off: false
EOF
cat >"$tmp/_grp.yaml" <<'EOF'
history_off: true
work_root: /work
envs:
  py: source /opt/py/bin/activate
  proxy: source /etc/proxy
repos:
  proj: {path: /shared/proj, shared: true}
dirs:
  logs: /work/logs
tools: {tmux: true}
EOF
cat >"$tmp/m-train-01.yaml" <<'EOF'
extends: _grp
role: train
envs:
  py: source /opt/py2/bin/activate
repos:
  mine: ~/src/mine
EOF
cat >"$tmp/m-infer-01.yaml" <<'EOF'
role: infer
tools: {tmux: false}
dirs: {logs: ~/logs}
EOF
cat >"$tmp/bad.yaml" <<'EOF'
gpu_mem_used: 3000
EOF

fail() { echo "FAIL: $*" >&2; exit 1; }
expect() { # expect <description> <haystack> <needle>
  [[ "$2" == *"$3"* ]] || fail "$1: missing [$3] in [$2]"
}

out="$("$here/rx" --dry-run m-train-01 --repo proj --task t1 --env py --env proxy -- echo hi)"
expect "task workdir" "$out" "cd /work/t1/proj"
expect "machine env overrides group" "$out" "source /opt/py2/bin/activate"
expect "env order" "$out" "activate && source /etc/proxy && echo hi"
expect "history off from group" "$out" "unset HISTFILE; set +o history"
expect "ssh options" "$out" "ssh -T -o BatchMode=yes -o ConnectTimeout=15 m-train-01"

out="$("$here/rx" --dry-run m-train-01 --repo mine -- ls)"
expect "tilde stays expandable" "$out" "cd ~/src/mine"

out="$("$here/rjob" --dry-run start m-train-01 job1 --repo proj -- sleep 1)"
expect "tmux session" "$out" "tmux new-session -d -s job1"
expect "remain-on-exit" "$out" "remain-on-exit on"
expect "owner tag" "$out" "@owner tester"
expect "log path" "$out" "/work/logs/job1.log"

out="$("$here/rjob" --dry-run start m-infer-01 job2 -- sleep 1)"
expect "nohup fallback" "$out" "nohup setsid"
expect "pid file" "$out" "~/logs/job2.pid"

out="$("$here/rjob" --dry-run stop m-train-01 job1 --rm-log)"
expect "stop checks owner" "$out" "@owner"
expect "stop removes log" "$out" "rm -f /work/logs/job1.log"

if "$here/rgit" --dry-run push m-train-01 --repo proj --branch b >/dev/null 2>&1; then
  fail "push into a shared repo must be refused"
fi
out="$("$here/rgit" --dry-run push m-train-01 --repo proj --task t1 --branch feat/x --checkout)"
expect "push to own copy" "$out" "git push m-train-01:/work/t1/proj +refs/heads/feat/x:refs/remotes/laptop/feat/x"
expect "checkout is ff-only" "$out" "merge --ff-only"
out="$("$here/rgit" --dry-run push m-train-01 --repo mine --branch b)"
expect "home-relative scp path" "$out" "m-train-01:src/mine"

if "$here/rx" --dry-run bad -- true >/dev/null 2>&1; then
  fail "unknown (dynamic) keys must be rejected"
fi
if "$here/rjob" --dry-run start m-train-01 'bad name' -- true >/dev/null 2>&1; then
  fail "job names with spaces must be rejected"
fi

out="$("$here/probe" --dry-run m-train-01 gpu git)"
expect "probe gpu" "$out" "nvidia-smi --query-gpu"
expect "probe git is lock-free" "$out" "--no-optional-locks"

out="$("$here/rgit" --dry-run clone m-train-01 --repo proj --task t1)"
expect "clone borrows objects" "$out" "git clone --quiet --shared /shared/proj /work/t1/proj"

echo "remote-machines: all checks passed"
