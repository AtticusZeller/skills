# sing-box Helper Scripts

DSW/tini containers do not provide a meaningful systemd user service. The main installer therefore deploys executable assets instead of asking the Agent to reconstruct scripts from Markdown:

- `assets/sbc-start` → `~/.local/bin/sbc-start`
- `assets/sbc-stop` → `~/.local/bin/sbc-stop`
- `assets/sbc-status` → `~/.local/bin/sbc-status`

## Runtime Model

`sbc-start` resolves the packaged sing-box binary through the Python environment owned by the uv-installed `sing-box-cli`. This avoids hardcoding a Python patch version or CPU architecture. It then starts sing-box with `nohup` and writes:

- PID: `~/.local/state/sbc/sbc.pid`
- log: `~/.local/state/sbc/sbc.log`

`sbc-stop` sends a normal termination signal, waits briefly, and force-stops only when the process does not exit.

`sbc-status` reports running, stopped, or stale-pid state and displays the latest log lines.

## Configuration Boundary

The installer intentionally does not create `~/.config/sing-box/config.json`, because subscription data and private endpoints must not enter this public repository. When the file is missing, setup completes and reports it as a manual action.

The helpers support two local overrides:

- `SBC_CONFIG`: alternate configuration path.
- `SBC_BINARY`: explicit sing-box executable when the uv-managed package is not used.

Keep the sing-box mixed inbound, shell proxy variables, Git proxy, and SSH forwarding on the same endpoint. If the default port is occupied, inspect the forwarding path before changing the proxy port.
