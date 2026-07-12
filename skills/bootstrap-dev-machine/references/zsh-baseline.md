# Server Zsh Baseline

Use this reference after the host package manager and proxy path are known. The reusable configuration is `../assets/zshrc.server`; it intentionally contains no tokens, private endpoints, or generated Powerlevel10k settings.

## Install The Shell

Install at least `zsh`, `git`, `curl`, `fzf`, and `bat` with the host package manager. On Debian/Ubuntu, the `bat` executable may be named `batcat`.

Install Oh My Zsh without entering a new shell or overwriting an existing `.zshrc`:

```bash
RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

Install Powerlevel10k:

```bash
zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
  "$zsh_custom/themes/powerlevel10k"
```

Install the external plugins used by the template:

```bash
zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
  "$zsh_custom/plugins/zsh-autosuggestions"
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
  "$zsh_custom/plugins/zsh-syntax-highlighting"
git clone --depth=1 https://github.com/Pilaton/OhMyZsh-full-autoupdate \
  "$zsh_custom/plugins/ohmyzsh-full-autoupdate"
git clone --depth=1 https://github.com/fdellwing/zsh-bat \
  "$zsh_custom/plugins/zsh-bat"
```

Skip a clone when its destination already exists.

## Deploy The Template

Resolve the installed skill directory first. For the Codex global install it is normally:

```bash
skill_dir="$HOME/.codex/skills/bootstrap-dev-machine"
```

Back up an existing configuration and install the public template:

```bash
if [[ -f "$HOME/.zshrc" ]]; then
  cp "$HOME/.zshrc" "$HOME/.zshrc.bak.$(date +%Y%m%d%H%M%S)"
fi
install -m 0644 "$skill_dir/assets/zshrc.server" "$HOME/.zshrc"
```

The template defaults proxy variables to `http://127.0.0.1:7890`. To use another endpoint, set `PROXY_URL` before starting zsh or edit the non-secret endpoint in the deployed file. Keep Git proxy settings aligned separately.

Do not put GitHub, Hugging Face, Weights & Biases, or other tokens in `.zshrc`. Authenticate with each tool's supported credential store.

## Prompt And Default Shell

Generate a machine-local prompt configuration instead of publishing the generated file:

```bash
zsh -ic 'p10k configure'
```

Set zsh as the login shell when the host permits it:

```bash
chsh -s "$(command -v zsh)"
```

In managed containers where `chsh` does not persist, start zsh from the terminal profile or invoke it explicitly.

## Validate

```bash
zsh -n "$HOME/.zshrc"
zsh -ic 'echo zsh-ready'
test -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
test -f "$HOME/.p10k.zsh"
```

If interactive startup reports a missing plugin, install that plugin at the exact directory named in the `plugins=(...)` list or remove it from the local list.
