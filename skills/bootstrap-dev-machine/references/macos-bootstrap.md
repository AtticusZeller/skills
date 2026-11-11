# macOS / MacBook Bootstrap

Use `scripts/bootstrap-dev-machine-macos.sh` as the single installation entry
point. Requires macOS, Xcode Command Line Tools, Homebrew, and a normal user
account. Apple Silicon and Intel use their native Homebrew prefixes. Keep the
personal skills checkout at `~/dev/skills`. Preview with `--dry-run` before setup.

## Tools and Configuration

- Homebrew manages Git, gh, ripgrep, jq, bat, fd, fzf, tmux, uv, Bash, coreutils, findutils, GNU sed,
  ShellCheck, the native sing-box core, Ghostty, its font, Codex CLI, and Claude Code.
- uv installs Python 3.12 and isolated `hf`, `wandb`, and `sbc` tools. `sbc` and
  `sbc-start` use the Homebrew core on macOS; the Python binary wheel is Linux-only.
- nvm installs Node 24; Miniforge installs Conda/Mamba at `~/miniforge3` from a
  pinned Darwin release with SHA256 verification. Base auto-activation is disabled.
- Oh My Zsh, Powerlevel10k, autosuggestions, highlighting, full-autoupdate, and bat
  plugins are cloned from their upstream repositories. The system `/bin/zsh` is
  retained. A shared `assets/p10k.zsh` prompt preset is deployed automatically;
  existing personal prompts are preserved. Read `zsh-baseline.md` for startup,
  completions, and local overrides.
- Exact Mac zsh and Ghostty assets are deployed by `install-macos-config.py`.
  Their hashes, backups, and locally modified files are kept separately from the
  Linux template state. Mac Ghostty configuration uses the Application Support path.
- Oh my tmux reuses the shared installer without stopping sessions. sing-box
  helpers are installed but no network proxy, TUN interface, or background service
  is enabled automatically. No CUDA, NVIDIA tools, DSW prompt, apt, or systemd setup
  is run. Proxy variables are set only when `PROXY_URL` is explicitly supplied.
- Personal and manifest-listed global agent skills are installed. The Context7
  CLI is installed, while account-backed setup is reported as a manual step.
- Mac-specific machine handoff templates create global instructions and the home
  README only when absent; Claude imports the existing shared instructions once.

## Options and Recovery

`--skip-packages`, `--skip-conda`, and `--skip-skills` retain externally managed
layers. `--configure-only` deploys the Mac assets and handoff without tool installs
(uv must already be available). Existing tools and clones are reused, and locally
edited managed files are preserved for manual merging. Private shell additions
belong in `~/.zshrc.local`. Restart with the same entry point after a failed phase.

`--set-default-terminal` is opt-in and requires Ghostty to be installed already. It runs
`set-default-terminal-macos.swift` before installing tools, using Apple's
NSWorkspace API to associate Unix executables and `.command` files with Ghostty.
The helper's `--check` mode reads and verifies these associations. macOS may ask
for user consent. Ordinary source files, URL schemes, Finder services, and
application-specific terminal preferences are not changed.

Run `scripts/check-dev-machine-macos.sh` after setup. Open a new Ghostty window
to load the shell; use `Cmd+Shift+,` to reload Ghostty's appearance settings.
Account credentials, GitHub login, Context7 account setup, sing-box private config,
and optional `p10k configure` choices remain local manual actions.

For the repository's legacy Linux regression tests on macOS, prepend Homebrew's
`opt/coreutils/libexec/gnubin`, `opt/findutils/libexec/gnubin`, and
`opt/gnu-sed/libexec/gnubin` directories to the validation process's `PATH`.
The Mac shell template does not override the system command implementations.
