# sing-box Helper Scripts Reference

Use this model on DSW/tini/container hosts where `systemctl` is missing or not meaningful. The goal is a simple user-level background process with a pid file and log file.

## Why Not systemctl

`sbc service enable` expects `systemctl`. On DSW-style hosts PID 1 is often `tini`, so systemd service management fails even when the `systemd` package is installed.

## Reference Layout

```text
~/.local/bin/sbc-start
~/.local/bin/sbc-stop
~/.local/bin/sbc-status
~/.local/state/sbc/sbc.pid
~/.local/state/sbc/sbc.log
```

## sbc-start Model

Use `nohup` and call the sing-box binary directly. This avoids CLI wrapper issues and keeps logs in a predictable place.

```bash
#!/usr/bin/env bash
set -euo pipefail

state_dir="${HOME}/.local/state/sbc"
pid_file="${state_dir}/sbc.pid"
log_file="${state_dir}/sbc.log"

mkdir -p "${state_dir}"

if [[ -f "${pid_file}" ]]; then
  pid="$(cat "${pid_file}")"
  if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
    echo "sbc is already running: pid ${pid}"
    exit 0
  fi
fi

binary="${HOME}/.local/share/uv/tools/sing-box-cli/lib/python3.12/site-packages/sing_box_bin/bin/sing-box-linux-amd64"
config="${HOME}/.config/sing-box/config.json"

nohup "${binary}" run -c "${config}" >>"${log_file}" 2>&1 &
pid="$!"
echo "${pid}" >"${pid_file}"
echo "started sbc: pid ${pid}"
echo "log: ${log_file}"
```

## sbc-stop Model

Stop by pid file, wait briefly, then force-kill only if the process does not exit.

```bash
#!/usr/bin/env bash
set -euo pipefail

state_dir="${HOME}/.local/state/sbc"
pid_file="${state_dir}/sbc.pid"

if [[ ! -f "${pid_file}" ]]; then
  echo "sbc is not running: no pid file"
  exit 0
fi

pid="$(cat "${pid_file}")"
if [[ -z "${pid}" ]] || ! kill -0 "${pid}" 2>/dev/null; then
  rm -f "${pid_file}"
  echo "sbc is not running"
  exit 0
fi

kill "${pid}"
for _ in {1..20}; do
  if ! kill -0 "${pid}" 2>/dev/null; then
    rm -f "${pid_file}"
    echo "stopped sbc: pid ${pid}"
    exit 0
  fi
  sleep 0.2
done

kill -9 "${pid}" 2>/dev/null || true
rm -f "${pid_file}"
echo "force stopped sbc: pid ${pid}"
```

## sbc-status Model

Report stale pid files and show the last log lines.

```bash
#!/usr/bin/env bash
set -euo pipefail

state_dir="${HOME}/.local/state/sbc"
pid_file="${state_dir}/sbc.pid"
log_file="${state_dir}/sbc.log"

if [[ -f "${pid_file}" ]]; then
  pid="$(cat "${pid_file}")"
  if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
    echo "sbc is running: pid ${pid}"
  else
    echo "sbc is not running: stale pid file"
  fi
else
  echo "sbc is not running"
fi

if [[ -f "${log_file}" ]]; then
  echo "log: ${log_file}"
  tail -n 20 "${log_file}"
fi
```

## Adaptation Notes

- Resolve the `binary` path after installing `sing-box-cli`; do not assume Python patch versions are identical across machines.
- Keep the listen port in `~/.config/sing-box/config.json` aligned with the user's SSH forwarding and shell proxy variables.
- If `127.0.0.1:7890` is occupied, check SSH forwarding before changing sing-box.
