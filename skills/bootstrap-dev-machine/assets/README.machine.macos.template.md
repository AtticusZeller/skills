# MacBook Development Machine

The macOS baseline uses Homebrew, the Apple-provided `/bin/zsh`, Oh My Zsh,
Powerlevel10k, Oh my tmux, and Ghostty. Linux CUDA/DSW setup is not run.

## Toolchain

- Python {{PYTHON_VERSION}}: `uv`; dependencies stay in project environments.
- Conda/Mamba: Miniforge at `~/miniforge3`, without automatic base activation.
- Node {{NODE_VERSION}}: nvm at `~/.nvm`; source `~/.nvm/nvm.sh` in non-interactive shells.
- CLI tools: ripgrep, fd, bat, fzf, jq, Git, gh, tmux, Codex, Claude Code, hf,
  Weights & Biases, and sing-box-cli (`sbc`).
- Proxying is opt-in with `PROXY_URL`; no fixed proxy or network service is started.
- GitHub, Hugging Face, Weights & Biases, Codex, Claude, and Context7 account setup
  remains local to the user. No credentials are included in this file.

## Configuration

- Shell: `~/.zshrc`; private additions: `~/.zshrc.local`.
- Prompt choices: run `p10k configure` in Ghostty when convenient.
- Ghostty: `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty`.
  Reload with `Cmd+Shift+,`; open a new window after a shell change.
- Tmux: `~/.config/tmux/tmux.conf` and `tmux.conf.local`.
- Personal skills repository: `~/dev/skills`.
- Shared agent rules: `~/.codex/AGENTS.md`, imported by `~/.claude/CLAUDE.md`.
- Managed configuration hashes: `~/.local/state/bootstrap-dev-machine/`.

Unmodified managed files update on rerun; replacements are backed up. Local edits
are preserved for manual merge. Existing machine handoff files are never replaced.
Mac default-terminal associations apply to Unix executables and `.command` files;
Finder services and applications with their own terminal preference are separate.

## Repeat Setup and Check

```bash
bash ~/dev/skills/skills/bootstrap-dev-machine/scripts/bootstrap-dev-machine-macos.sh --dry-run
bash ~/dev/skills/skills/bootstrap-dev-machine/scripts/bootstrap-dev-machine-macos.sh
bash ~/dev/skills/skills/bootstrap-dev-machine/scripts/check-dev-machine-macos.sh
```

GPU/CUDA utilities are omitted because this is a Mac workstation. sing-box helpers
are installed, but the proxy is started only after supplying a private config at
`~/.config/sing-box/config.json`. Never store subscription URLs or tokens here.
