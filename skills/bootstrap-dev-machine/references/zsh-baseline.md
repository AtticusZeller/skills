# Server Zsh Baseline

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

When `~/.p10k.zsh` is absent, the installer deploys `assets/p10k.zsh` (lean, 2 lines, nerdfont-v3, transient prompt). An existing `~/.p10k.zsh` is never overwritten. The template needs a Nerd Font in the client terminal; otherwise run `p10k configure` on that machine.

Set a different proxy by exporting `PROXY_URL` before running the installer. Keep Git proxy settings on the same endpoint.

Do not place GitHub, Hugging Face, Weights & Biases, or other tokens in `.zshrc`. Authenticate with each tool's supported credential store.

## Diagnosis

Use `zsh -n ~/.zshrc` for syntax failures. For interactive startup errors, check:

1. `~/.oh-my-zsh/oh-my-zsh.sh` exists.
2. Every external name in `plugins=(...)` has a matching directory under the Oh My Zsh custom plugin directory.
3. The Powerlevel10k theme directory exists.
4. Miniforge, NVM, and optional CUDA directories are only loaded when present.

The machine checker performs the same path and syntax checks without modifying the shell configuration.
