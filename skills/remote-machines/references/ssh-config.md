# SSH Connection Setup

## Connection reuse

Put this block **last** in `~/.ssh/config`. ssh_config uses the first value it finds for each
option, so per-host settings above it (ProxyJump, RemoteForward, an existing ControlPath) win.

```sshconfig
Host *
    ControlMaster auto
    ControlPath ~/.ssh/cm/%C
    ControlPersist 10m
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

Create the socket directory once: `mkdir -m 700 -p ~/.ssh/cm`. `%C` is a hash of the connection
(local host, remote host, port, user, jump), which keeps socket paths short.

Do not touch `Include`, `ProxyJump`, or other existing host settings when adding the block. Show
the user a diff and back up the file (`~/.ssh/config.bak-YYYYMMDD`) before changing it.

## Checking and recovering

| Situation | Command |
| --- | --- |
| Is a master running? | `ssh -O check <alias>` → `Master running (pid=...)` |
| Hung or stale connection (commands block, network changed) | `ssh -O exit <alias>`, then reconnect |
| Socket left after a crash | `ssh -O exit <alias>`; if that fails, remove the matching file in `~/.ssh/cm/` |
| Bypass the master for one command | `ssh -o ControlMaster=no -o ControlPath=none <alias> ...` |

After switching Wi-Fi or VPN, run `ssh -O exit` for hosts on the old network: the master keeps
its old TCP connection until ServerAlive gives up (about 3 minutes).

RemoteForward and LocalForward only take effect on the connection that starts the master. To add
a forward later, use `ssh -O forward -R ... <alias>` or exit the master first.

## Naming

Host aliases follow `<org>-<role>-<id>`: `org` is the owner (company code, `lab`, `me`),
`role` is `train` / `infer` / `robot` (or omitted for personal hosts), `id` tells peers apart. Group
hosts in `~/.ssh/config` by org with a comment saying how each group is reachable.
