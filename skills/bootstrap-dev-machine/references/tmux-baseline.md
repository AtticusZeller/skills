# Tmux Baseline

The bootstrap uses [Oh my tmux!](https://github.com/gpakosz/.tmux), matching the tmux section of the user's Scholar handbook at `40_handbook/DevOps/OS/Ubuntu/Terminal.md`.

`scripts/install-tmux-baseline.sh` clones the upstream repository to `~/.local/share/oh-my-tmux`, links its `.tmux.conf` to `~/.config/tmux/tmux.conf`, and copies its `.tmux.conf.local` to `~/.config/tmux/tmux.conf.local` only when absent, appending the bundled `assets/tmux-defaults.conf`. This enables mouse selection, resizing, and right-click command menus by default. If `XDG_CONFIG_HOME` is set, it replaces `~/.config`. No upstream source is vendored into the skill.

Reruns reuse the checkout and preserve the local customization file. Edit `tmux.conf.local`, never the linked upstream file. Existing conflicting main configurations, including `~/.tmux.conf` which takes precedence, stop deployment before changes; review and move them aside before retrying.

For a tmux-only installation or repair, run the helper with `--dry-run`, then without that flag. It never kills a server. New servers load the configuration automatically. On an existing server, run `tmux source-file ~/.config/tmux/tmux.conf` (adjust for `XDG_CONFIG_HOME`), or use the prefix followed by `r` once the baseline is loaded.

The default prefix is `Ctrl+b`, with `Ctrl+a` as a second prefix. Prefix followed by `-` stacks panes; `_` places them side by side; `h/j/k/l` navigates panes; `[` enters copy mode; `d` detaches. The upstream default theme is used without additional plugins.

Right-click a pane for its split, zoom, and copy menu, or a window/session name on the status line for its menu. Prefix followed by `m` toggles mouse mode. Existing customization files are preserved on reruns; to enable mouse mode on an older installation, uncomment or add `set -g mouse on` in the local file and run `tmux set -g mouse on` for the running server.
