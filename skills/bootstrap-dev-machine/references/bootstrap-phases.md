# Bootstrap Phases

The normal path is the idempotent installer at `../scripts/bootstrap-dev-machine.sh`. Run it once, inspect its final validation and manual-follow-up summary, and rerun the same command after fixing any reported blocker.

The installer supports a read-only preview:

```bash
bash scripts/bootstrap-dev-machine.sh --dry-run
```

Do not manually replay individual phase commands unless the installer reports an unsupported host or a specific phase failure.

## Inputs

The defaults match the DSW/container baseline:

- Proxy: `PROXY_URL=http://127.0.0.1:7890`
- Python: `BOOTSTRAP_PYTHON_VERSION=3.12`
- Node: `BOOTSTRAP_NODE_VERSION=24`
- nvm installer: `BOOTSTRAP_NVM_VERSION=v0.40.5`
- Personal skills checkout: `PERSONAL_SKILLS_DIR=$HOME/skills`

Use `--no-proxy` only when the host has direct network access. Use `--skip-packages`, `--skip-skills`, or `--skip-context7` when those layers are managed externally.

## Automated Phases

The entry script performs these phases in order:

1. Exports lower- and upper-case proxy variables and aligns Git proxy settings.
2. Detects apt, dnf, or yum; installs required packages and attempts optional developer utilities.
3. Installs uv, Python, sing-box-cli, nvitop, and Weights & Biases.
4. Deploys `sbc-start`, `sbc-stop`, and `sbc-status` for non-systemd hosts.
5. Installs nvm and Node, then sets the requested Node version as default.
6. Installs Claude Code and the Hugging Face CLI; checks other developer CLIs.
7. Installs Oh My Zsh, Powerlevel10k, plugins, and the public server `.zshrc`.
8. Installs personal and external agent skills from the repository manifest.
9. Runs `check-dev-machine.sh` and prints all remaining manual work together.

Each phase is safe to rerun: existing tools and clones are reused, and `.zshrc` is backed up only when the deployed template differs.

## Intentionally Manual

The script cannot safely automate account or machine-private state:

- sing-box subscription/configuration content;
- GitHub, Hugging Face, Weights & Biases, and Context7 authentication;
- interactive Powerlevel10k prompt choices;
- handoff details specific to the machine;
- cc-switch installation when no supported system package is available.

These items appear once in the final summary rather than interrupting the automated phases.

## Failure Handling

Required-phase failures stop immediately and identify the phase and line. Optional package or account-backed setup failures become warnings so independent phases can finish.

Use the focused references only after a failure:

- `zsh-baseline.md` for shell customization and startup diagnosis.
- `sbc-service-scripts.md` for sing-box helper behavior and configuration boundaries.
