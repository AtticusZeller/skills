# Ghostty Baseline

On a systemd desktop, enable background startup at login with `systemctl enable --user app-com.mitchellh.ghostty.service`. Use `ghostty +new-window` to request a window over D-Bus; activation starts Ghostty if necessary. The template exits Ghostty five minutes after its last window closes. See the [systemd and D-Bus documentation](https://ghostty.org/docs/linux/systemd).

The bootstrap installs [Ghostty](https://ghostty.org) on apt/dpkg hosts with the [ghostty-ubuntu](https://github.com/mkasberg/ghostty-ubuntu) installer command, then deploys the bundled configuration.

## Configuration Path

Ghostty 1.2.3+ reads `$XDG_CONFIG_HOME/ghostty/config.ghostty` before the legacy `config` filename; the path defaults to `~/.config/ghostty/config.ghostty`. `scripts/install-ghostty-terminal.sh` writes that file from `../assets/ghostty-config.ghostty` with mode `0644`.

The template sets:

- `/usr/bin/zsh` as the terminal command, matching the zsh baseline;
- JetBrainsMono Nerd Font at 15 pt, with balanced padding and an 80x20 window;
- the Ubuntu palette, bar cursor, and copy-on-select;
- `Ctrl+Shift` copy/paste, search, font-size keys, and `Shift+Enter` for coding-agent multiline input.

## Installer Command

The installation command is:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh)"
```

It runs only when `ghostty` is absent. The installer downloads a release `.deb` and installs it with `apt-get`; it supports Ubuntu 24.04, 26.04, and 26.10, Debian trixie/forky, Kali 2025, Sparky 8, and the matching Mint or Zorin releases, and exits nonzero elsewhere. The bootstrap turns a failed install into a warning and still deploys the configuration, so a later manual install inherits it.

Because the installer downloads the `.deb` into the current directory, the wrapper runs it in a temporary directory. Use `--skip-install` to deploy only the configuration; use `--skip-ghostty` on the bootstrap to skip both.

## macOS / MacBook Adaptation

The bundled asset remains the Linux baseline. Its inline comments identify the
macOS adaptations; the Linux bootstrap and `install-ghostty-terminal.sh` are not
macOS installers. On a MacBook, install Ghostty with Homebrew:

```bash
brew install --cask ghostty
```

Back up an existing config, copy `assets/ghostty-config.ghostty` to
`~/Library/Application Support/com.mitchellh.ghostty/config.ghostty`, and apply
these changes to the local copy:

- Change `command` to `/bin/zsh`; macOS does not ship `/usr/bin/zsh`.
- Set `quit-after-last-window-closed = false` for the usual Mac behavior of
  keeping the app running after closing its last window. Omit
  `quit-after-last-window-closed-delay`, which is implemented only on Linux.
- Keep Ghostty's default macOS shortcuts: `Cmd+C` / `Cmd+V` for copy/paste,
  `Cmd+T` / `Cmd+N` for tabs/windows, and `Cmd+Shift+,` to reload config. The
  template's additional `Ctrl` bindings do not clear these defaults. Omit the
  `Shift+Insert` binding because macOS has no primary selection clipboard.
- Keep the Ubuntu palette, 15 pt font, bar cursor, copy-on-select, and
  `Shift+Enter` binding. The latter sends ESC followed by CR; multiline behavior
  depends on the receiving application.

To use the requested font family rather than the embedded fallback, install it
with `brew install --cask font-jetbrains-mono-nerd-font`. Check `ghostty +list-fonts`;
if the available monospaced family is `JetBrainsMono Nerd Font Mono`, use that
name for all four `font-family` settings in the local copy.

The macOS-specific config is loaded after the XDG config and can override it;
avoid maintaining conflicting copies. Validate with `ghostty +validate-config`
and inspect the effective values with `ghostty +show-config`. After a shell
command change, open a new terminal window. See the official
[configuration paths](https://ghostty.org/docs/config#file-location) and
[quit-delay reference](https://ghostty.org/docs/config/reference#quit-after-last-window-closed-delay).

## Default Terminal on Ubuntu

After installing Ghostty, select it for programs that use Debian's `x-terminal-emulator` alternative:

```bash
sudo update-alternatives --set x-terminal-emulator /usr/bin/ghostty
```

For applications that use the GNOME terminal preference, also run:

```bash
gsettings set org.gnome.desktop.default-applications.terminal exec ghostty
```

Desktop shortcuts and file managers may use their own terminal settings.

## Local Changes and Recovery

- `~/.local/state/bootstrap-dev-machine/ghostty-config.sha256` records the last deployed template. An unmodified deployment is replaced when the template changes, and the previous file is backed up as `config.ghostty.bak.<timestamp>`.
- A configuration edited since the last deployed template is preserved; the installer prints the asset path for a manual merge. A configuration found without deployment state is backed up before replacement.
- A non-regular file at the target path stops the installer instead of being replaced.
- Press `Ctrl+Shift+,` to reload the configuration at runtime, or restart Ghostty for options that cannot be reloaded. `ghostty +show-config` prints effective values, and `ghostty +show-config --default --docs` lists every option.

## Fonts

The template requests JetBrainsMono Nerd Font. Ghostty embeds a JetBrains Mono default with nerd-font glyphs, so a host without that family falls back to the embedded font; install it or change `font-family` to match the intended rendering.
