# Zsh Baselines

## macOS / MacBook

Use `bootstrap-dev-machine-macos.sh`, which deploys `assets/zshrc.macos` through
`install-macos-config.py`. It keeps Apple's `/bin/zsh`, loads the appropriate
Apple Silicon or Intel Homebrew environment, and installs the same Oh My Zsh,
Powerlevel10k, autosuggestions, syntax highlighting, bat, and update plugins.
It also loads uv/uvx completions, fzf, nvm/Node, and Miniforge Conda/Mamba hooks.
The base Conda environment is not auto-activated. The nearest project `.venv`
is activated on startup and directory changes.

CUDA, DSW rules, Linux package-manager hooks, and forced proxy settings are not
included. Proxying is enabled only with an explicitly supplied `PROXY_URL`.
The exported Ubuntu `assets/p10k.zsh` preset is deployed to `~/.p10k.zsh`; no wizard
is required. It preserves the lean two-line style, left frame, compact spacing,
Nerd Font v3 icons, 24-hour time, and transient prompt. Use
`~/.zshrc.local` for private additions and `p10k configure` for optional changes.
Managed updates back up replaced files and preserve local edits using stored
hashes. Open a new Ghostty window to load a changed shell configuration.

## Linux Server

The main installer owns shell installation and deployment. This reference describes the resulting state and the few choices that remain local to each machine.

## Automated State

`bootstrap-dev-machine.sh` installs and configures:

- zsh, Oh My Zsh, and Powerlevel10k;
- `zsh-autosuggestions`, `zsh-syntax-highlighting`, `ohmyzsh-full-autoupdate`, and `zsh-bat`;
- `assets/zshrc.server` as `~/.zshrc`, with a timestamped backup when content changes;
- `$HOME/.local/bin`, optional CUDA paths, uv/uvx completion, Miniforge/conda/mamba initialization, and NVM loading;
- startup activation of the nearest parent `.venv`;
- lower- and upper-case proxy variables using `PROXY_URL`.

Existing clones are reused. The installer records the deployed template hash; later runs update an unchanged managed file but preserve local edits and report a manual merge.

## Local Choices

When `~/.p10k.zsh` is absent, the Linux installer deploys `assets/p10k.zsh` (lean,
2 lines, nerdfont-v3, transient prompt). Existing Linux prompt files are never
overwritten. The Mac entry point reuses that exact asset through
`install-prompt-config.sh`: it preserves custom prompts and updates an unchanged
managed template with a backup. The wizard is optional on both platforms.

Set a different proxy by exporting `PROXY_URL` before running the installer. Keep Git proxy settings on the same endpoint.

Do not place GitHub, Hugging Face, Weights & Biases, or other tokens in `.zshrc`. Authenticate with each tool's supported credential store.

## Diagnosis

Use `zsh -n ~/.zshrc` for syntax failures. For interactive startup errors, check:

1. `~/.oh-my-zsh/oh-my-zsh.sh` exists.
2. Every external name in `plugins=(...)` has a matching directory under the Oh My Zsh custom plugin directory.
3. The Powerlevel10k theme directory exists.
4. Miniforge, NVM, and optional CUDA directories are only loaded when present.

The machine checker performs the same path and syntax checks without modifying the shell configuration.
