# AtticusZeller Skills

Personal agent skills and bootstrap helpers for development machines.

## Install

List available personal skills:

```bash
npx skills add AtticusZeller/skills --list --full-depth
```

Install the development-machine bootstrap skill globally:

```bash
npx skills add AtticusZeller/skills --skill bootstrap-dev-machine -g -a codex -a claude-code -a cursor -y --full-depth
```

This skill provides an idempotent one-shot installer for the full machine baseline, including public machine handoff docs, a server `.zshrc`, Oh My Zsh, Powerlevel10k, shell plugins, CUDA, uv, Miniforge/conda, NVM, proxy variables, and non-systemd sing-box helpers.

On Alibaba Cloud DSW, run its installer with `--enable-dsw-persistent-prompt` to back up and append the OSS persistence rule to `~/.codex/AGENTS.md`:

```bash
bash "$HOME/.agents/skills/bootstrap-dev-machine/scripts/bootstrap-dev-machine.sh" --enable-dsw-persistent-prompt
```

Install the personal skills maintenance skill globally:

```bash
npx skills add AtticusZeller/skills --skill manage-personal-skills -g -a codex -a claude-code -a cursor -y --full-depth
```

Install the repository initialization skill globally:

```bash
npx skills add AtticusZeller/skills --skill init-repo-agents -g -a codex -a claude-code -a cursor -y --full-depth
```

This skill renders repository agent rules and portable docs scaffolding through bundled idempotent scripts, then checks template fidelity and preservation of existing content.

Install the GitHub fork workflow skill globally:

```bash
npx skills add AtticusZeller/skills --skill git-fork-workflow -g -a codex -a claude-code -a cursor -y --full-depth
```

Install all personal skills:

```bash
npx skills add AtticusZeller/skills --skill '*' -g -a codex -a claude-code -a cursor -y --full-depth
```

These examples name the target agents explicitly. PromptScript supports project-level skills only, so do not use `-g` with `-a promptscript`.

## Update Installed Skills

Refresh installed skills from their recorded sources:

```bash
npx skills update
```

When prompted, choose `Global` to check and update all globally installed personal and third-party skills, including skills from `AtticusZeller/skills`.

## External Global Skills

This repository does not vendor third-party skills. The usual external global skills are recorded in `manifests/global-skills.json`.

Dry-run the install commands:

```bash
bash scripts/install-global-skills.sh --dry-run
```

Install them:

```bash
bash scripts/install-global-skills.sh
```

The script runs `npx skills add <repo> --skill <skill> -g -y` for each manifest entry. For Context7, it also runs:

```bash
npx ctx7 setup --cli --claude --codex -y
```

If Context7 requires authentication, complete its login flow; no token is stored in this repository.

## Repository Maintenance

Validate before committing:

```bash
bash scripts/validate-skills.sh
npx skills add . --list --full-depth
bash scripts/install-global-skills.sh --dry-run
```

Publish updates:

```bash
git status --short
git add .
git commit -m "Update personal skills"
git push
```

## Safety

Do not commit secrets, tokens, PATs, private subscriptions, SSH keys, node credentials, API keys, or private machine config.
