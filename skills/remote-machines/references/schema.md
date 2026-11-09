# Registry Schema

One file per machine: `~/.config/remote-machines/machines/<alias>.yaml`, where `<alias>` is the
`Host` name in `~/.ssh/config`. Aliases follow `<org>-<role>-<id>` (e.g. `acme-train-01`,
`lab-4090`, `me-vps`).

The registry holds only **static** facts: things that stay true for weeks. Scripts reject unknown
top-level keys, so dynamic state cannot slip in under a new name.

## Fields

| Field | Kind | Meaning |
| --- | --- | --- |
| `extends` | static | Shared file name(s) without `.yaml`, e.g. `_acme-train`. |
| `org` | static | Owner of the machine: company code, `lab`, `me`. |
| `role` | static | `train` / `infer` / `robot` / `other`. |
| `network` | static | How it is reachable: `public`, `company-wifi`, `campus`, `tailscale`, `jump`. |
| `reach` | static | One line on prerequisites, e.g. "laptop on Wi-Fi X" or "via <alias>". |
| `hardware` | static | `gpu: {model, count, mem}`, `cpu`, `mem_gb`. |
| `tools` | static | `{tmux: true, rg: false, uv: true, docker: false, git: true, ...}`. `rjob` uses `tmux`. |
| `repos` | static | `name: path` or `name: {path, shared: true}`. Shared repos are never written by `rgit`. |
| `work_root` | static | Parent of your own work copies: `<work_root>/<task>/<repo>`. |
| `envs` | static | `name: activation command`, e.g. conda, venv, `uv`, or a proxy `source` line. |
| `dirs` | static | `data`, `checkpoints`, `logs`, ... ; `dirs.logs` is where `rjob` writes `<name>.log`. |
| `history_off` | static | Prefix remote commands with `unset HISTFILE; set +o history`. |
| `shared` | static | `true` when other people use the machine. |
| `shared_rules` | static | List of rules specific to this machine, e.g. "never edit /data/repo". |
| `risk` | static | `normal` / `high`. Robot clients are `high`. |
| `confirm_ops` | static | Operations that need the user's confirmation on a `high` machine. |
| `owner` | static | Tag written to tmux `@owner`; defaults to the local user name. |
| `notes` | static | Other durable experience. |
| `todo` | static | Fields still waiting for a human; delete entries once filled. |

Never write: GPU memory or utilisation, disk free space, running jobs or sessions, git branch or
dirty state, uptime, IPs/ports/users/keys (they belong to `~/.ssh/config`), and any password,
token, or key. Use `probe` for live state.

## Reuse across machines

Load order: `_defaults.yaml` → each `extends` file in order → `<alias>.yaml`. Mappings merge by
key recursively, so a machine can add one env or override one path; scalars and lists replace.
Files starting with `_` are never machines.

- `_defaults.yaml`: values for every machine, e.g. `owner`.
- `_<group>.yaml`: values shared by a batch, e.g. the envs, shared repos, proxy line, and
  `shared_rules` of identical training servers on one storage cluster.

## Example

```yaml
# _acme-train.yaml
org: acme
role: train
network: public
shared: true
history_off: true
work_root: /root/localstorage
envs:
  train: source /root/miniforge3/etc/profile.d/conda.sh && conda activate train
  proxy: source /public/bin/network_accelerate
repos:
  model: {path: /root/data/model, shared: true}
shared_rules:
  - Never edit /root/data/model; clone it with rgit clone.
```

```yaml
# acme-train-01.yaml
extends: _acme-train
hardware: {gpu: {model: NVIDIA H100 80GB HBM3, count: 8, mem: 81559 MiB}, mem_gb: 2015}
tools: {tmux: true, rg: false, uv: true, git: true}
dirs: {logs: /root/localstorage/logs}
```
