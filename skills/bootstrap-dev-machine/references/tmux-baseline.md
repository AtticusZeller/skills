# Tmux Baseline

The bootstrap uses [Oh my tmux!](https://github.com/gpakosz/.tmux), matching the tmux section of the user's Scholar handbook at `40_handbook/DevOps/OS/Ubuntu/Terminal.md`.

`scripts/install-tmux-baseline.sh` clones the upstream repository to `~/.local/share/oh-my-tmux`, links its `.tmux.conf` to `~/.config/tmux/tmux.conf`, and copies its `.tmux.conf.local` to `~/.config/tmux/tmux.conf.local` only when absent, appending the bundled `assets/tmux-defaults.conf`. This enables mouse selection, resizing, and right-click command menus by default. If `XDG_CONFIG_HOME` is set, it replaces `~/.config`. No upstream source is vendored into the skill.

Reruns reuse the checkout and preserve the local customization file. Edit `tmux.conf.local`, never the linked upstream file. Existing conflicting main configurations, including `~/.tmux.conf` which takes precedence, stop deployment before changes; review and move them aside before retrying.

For a tmux-only installation or repair, run the helper with `--dry-run`, then without that flag. It never kills a server. New servers load the configuration automatically. On an existing server, run `tmux source-file ~/.config/tmux/tmux.conf` (adjust for `XDG_CONFIG_HOME`), or use the prefix followed by `r` once the baseline is loaded.

The default prefix is `Ctrl+b`, with `Ctrl+a` as a second prefix. Prefix followed by `-` stacks panes; `_` places them side by side; `h/j/k/l` navigates panes; `[` enters copy mode; `d` detaches. The upstream default theme is used without additional plugins.

Right-click a pane for its split, zoom, and copy menu, or a window/session name on the status line for its menu. Prefix followed by `m` toggles mouse mode. Existing customization files are preserved on reruns; to enable mouse mode on an older installation, uncomment or add `set -g mouse on` in the local file and run `tmux set -g mouse on` for the running server.

## Missing application colours

New local configurations also append `COLORTERM` to `update-environment`, so attaching from a real terminal refreshes the session's colour capability. Existing local files are preserved; add this setting manually when upgrading. This does not change the environment of an already running shell or application.

Inspect the real terminal, tmux global and affected session environments, and the affected application's environment before changing colour settings. Agent command runners often provide `TERM=dumb`, empty `COLORTERM`, and `NO_COLOR=1`; starting a tmux server from that environment can pass these values to new panes. `check-dev-machine.sh` warns about the invoking environment and a reachable default tmux server; it does not inspect every socket, session, or running application. Launch interactive servers from a real terminal instead of the agent runner. Do not hardcode `TERM` in the shell template or unconditionally remove an intentional `NO_COLOR` preference.

When `NO_COLOR` was accidentally inherited, mark it removed from the global environment with `tmux set-environment -gr NO_COLOR`; if the affected session explicitly sets it, also use `tmux set-environment -r -t <session> NO_COLOR`. Existing shells still need `unset NO_COLOR`, and applications must be restarted. To resume Codex from an affected shell, use `env -u NO_COLOR codex resume`.

For confirmed truecolour terminals, use `tmux_conf_24b_colour=true` in the local customization file, or on tmux 3.2+ add a matching `terminal-features` RGB entry (for example `set -as terminal-features ",xterm-256color:RGB"`). Match the actual outer terminal; do not advertise RGB for all terminals. Reload the configuration and detach/reattach so the client renegotiates its capabilities. `COLORTERM` alone does not prove tmux enabled RGB. See the [tmux colour FAQ](https://github.com/tmux/tmux/wiki/FAQ#how-do-i-use-rgb-colour).
