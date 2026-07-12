# Server Zsh Baseline

The main installer owns shell installation and deployment. This reference describes the resulting state and the few choices that remain local to each machine.

## Automated State

`bootstrap-dev-machine.sh` installs and configures:

- zsh, Oh My Zsh, and Powerlevel10k;
- `zsh-autosuggestions`, `zsh-syntax-highlighting`, `ohmyzsh-full-autoupdate`, and `zsh-bat`;
- `assets/zshrc.server` as `~/.zshrc`, with a timestamped backup when content changes;
- `$HOME/.local/bin`, optional CUDA paths, uv/uvx completion, and NVM loading;
- startup activation of the nearest parent `.venv`;
- lower- and upper-case proxy variables using `PROXY_URL`.

Existing clones are reused. The installer records the deployed template hash; later runs update an unchanged managed file but preserve local edits and report a manual merge.

## Local Choices

Powerlevel10k configuration remains machine-local because its wizard is interactive and depends on terminal font capabilities. If `~/.p10k.zsh` is absent, the installer reports `p10k configure` as a final manual action.

Set a different proxy by exporting `PROXY_URL` before running the installer. Keep Git proxy settings on the same endpoint.

Do not place GitHub, Hugging Face, Weights & Biases, or other tokens in `.zshrc`. Authenticate with each tool's supported credential store.

## Diagnosis

Use `zsh -n ~/.zshrc` for syntax failures. For interactive startup errors, check:

1. `~/.oh-my-zsh/oh-my-zsh.sh` exists.
2. Every external name in `plugins=(...)` has a matching directory under the Oh My Zsh custom plugin directory.
3. The Powerlevel10k theme directory exists.
4. NVM and optional CUDA directories are only loaded when present.

The machine checker performs the same path and syntax checks without modifying the shell configuration.
