# AtticusZeller Skills

Personal agent skills and bootstrap helpers for development machines.

## Install

List available personal skills:

```bash
npx skills add AtticusZeller/skills --list --full-depth
```

Install the development-machine bootstrap skill globally:

```bash
npx skills add AtticusZeller/skills --skill bootstrap-dev-machine -g -a codex -a claude-code -a pi -y --full-depth
```

This skill provides an idempotent one-shot installer for the full machine baseline, including shared agent instructions, a Linux workstation `.zshrc`, ripgrep (`rg`) for agent-friendly code and document search, Oh My Zsh, Powerlevel10k, shell plugins, Oh my tmux, a Ghostty terminal baseline, a [Herdr TUI preset](skills/bootstrap-dev-machine/assets/herdr-config.toml), a Claude Code statusline, CUDA, uv, Miniforge/conda/mamba, NVM, proxy variables, and non-systemd sing-box helpers.

Global agent instructions live in `~/.codex/AGENTS.md`; `~/.claude/CLAUDE.md` imports that file with `@../.codex/AGENTS.md`. The installer creates the global file only when absent and preserves existing rules.

After installing Pi, optionally apply the portable Pi profile from the checkout. The profile includes an append prompt, `tokyo-footer`, compact Bash display, and settings with npm package references. The installer requires Bash and `jq`:

```bash
bash skills/bootstrap-dev-machine/scripts/install-pi-config.sh --dry-run
bash skills/bootstrap-dev-machine/scripts/install-pi-config.sh
```

This preserves existing files and settings (including package lists), backs up `settings.json` before filling missing defaults, and links Pi to shared Codex instructions if available. Restart Pi or run `/reload` to load the profile. Pi resolves configured packages on startup; log in separately. The footer's quota display needs a locally authenticated Codex CLI. Credentials, sessions, caches, Orca-managed extensions, and separately managed Trail of Bits hooks are excluded.

On Alibaba Cloud DSW, run its installer with `--enable-dsw-persistent-prompt` to back up and append the OSS persistence rule to `~/.codex/AGENTS.md`:

```bash
bash "$HOME/.agents/skills/bootstrap-dev-machine/scripts/bootstrap-dev-machine.sh" --enable-dsw-persistent-prompt
```

On macOS / MacBook, use the Homebrew variant, including Mac-specific zsh and
Ghostty settings, nvm/Node, uv/Python, Miniforge, and Oh my tmux. Proxying is opt-in;
Linux CUDA/DSW setup is skipped. Add `--set-default-terminal` only when requesting
Ghostty's executable and `.command` associations:

```bash
bash "$HOME/.agents/skills/bootstrap-dev-machine/scripts/bootstrap-dev-machine-macos.sh" --dry-run
bash "$HOME/.agents/skills/bootstrap-dev-machine/scripts/bootstrap-dev-machine-macos.sh"
```

On Windows, run the PowerShell variant from a non-elevated PowerShell. It installs command-line tools with Scoop, GUI applications from `assets/winget-apps.txt` with winget, and skips Conda, zsh, and tmux:

```powershell
powershell -ExecutionPolicy Bypass -File "$HOME\.agents\skills\bootstrap-dev-machine\scripts\bootstrap-dev-machine.ps1" -DryRun
```

On a configured Linux or macOS machine, `doctor.sh` reports which packages, third-party skills, personal skills and configs differ from this repository. It is read-only unless you pass `--sync` or `--ignore`:

```bash
bash ~/skills/skills/bootstrap-dev-machine/scripts/doctor.sh
```

Install the personal skills maintenance skill globally:

```bash
npx skills add AtticusZeller/skills --skill manage-personal-skills -g -a codex -a claude-code -a pi -y --full-depth
```

Install the repository initialization skill globally:

```bash
npx skills add AtticusZeller/skills --skill init-repo-agents -g -a codex -a claude-code -a pi -y --full-depth
```

This skill creates a human-owned collaboration baseline: the human decides intent,
scope, architecture, interfaces, task decomposition, and acceptance; the agent
implements and verifies. Tasks use `Change + Observable Evidence`, `CLAUDE.md`
imports the authoritative `AGENTS.md`, and project context is organized under
area-level `plan.md`, `log.md`, and `overview.md` files. Reusable commands live
in `docs/cmd.md`, never in a repository-root command notebook.

The initializer is create-only and refuses to replace custom rule files. Existing
repositories are updated through an inspected, user-confirmed patch rather than a
managed block. Common Skills are recorded with explicit triggers and are never
chained into an automatic lifecycle.

Install the plan-driven feature development skill globally:

```bash
npx skills add AtticusZeller/skills --skill develop-feature -g -a codex -a claude-code -a pi -y --full-depth
```

This skill agrees a plan with the human first, then lets that plan govern
implementation, an external code review, static checks, documentation sync, and
closeout into `docs/<area>/log.md`.

Install the disk cleanup skill globally:

```bash
npx skills add AtticusZeller/skills --skill disk-cleanup -g -a codex -a claude-code -a pi -y --full-depth
```

This skill audits disk usage across the **whole filesystem** — not just `$HOME` —
ranks every finding by how long it has gone unused, and returns a risk-tiered
deletion plan that the human executes. The agent owns measure, rank, classify,
and report; the human owns the decision. It never deletes anything itself.

Ranking is by `mtime`, never `atime`: under ext4 `relatime` the access time is
unreliable and any scan refreshes it, which inverts the ordering. The included
`scripts/disk-triage.sh` is a read-only scanner — a regression test enforces
that it contains no destructive command — and `references/classification.md`
records the tier definitions, the never-delete list, and the owner's confirmed
decision profile.

Install the remote machines skill globally:

```bash
npx skills add AtticusZeller/skills --skill remote-machines -g -a codex -a claude-code -a pi -y --full-depth
```

This skill treats every SSH host as an object. Static facts (role, hardware, tools, repos, envs,
directories, sharing rules, risk level) live in a private local registry
`~/.config/remote-machines/machines/<alias>.yaml`, which is never part of this repository; live
state comes from a read-only `probe`. `rx` runs a command with the registered workdir and envs,
`rjob` runs tmux (or nohup) background jobs tagged with an owner, and `rgit` ships local commits
to your own work copy on a shared server without pushing to GitHub first. `bootstrap` drafts the
registry from `~/.ssh/config` plus one read-only probe per host. Scripts need only `uv` locally;
`scripts/test-remote-machines.sh` checks registry merging and command composition without SSH.

Install the Claude-to-Codex memory sync skill globally:

```bash
npx skills add AtticusZeller/skills --skill claude-memory-to-codex -g -a codex -a claude-code -a pi -y --full-depth
```

This skill mirrors Claude Code auto-memory files into Codex's `ad_hoc` memory extension
(`~/.codex/memories/extensions/ad_hoc/notes/`), one note per memory, so Codex's own consolidation
folds them into its memory. `scripts/sync-claude-memory` is idempotent, skips projects whose
directory is gone, reads exclusions from `~/.config/claude-memory-to-codex/exclude.txt`, and only
deletes its own notes with `--prune`. `scripts/test-sync-claude-memory.sh` checks note format,
idempotency, updates, and pruning in a temporary home.

Install all personal skills:

```bash
npx skills add AtticusZeller/skills --skill '*' -g -a codex -a claude-code -a pi -y --full-depth
```

These examples name the target agents explicitly. PromptScript supports project-level skills only, so do not use `-g` with `-a promptscript`.

## Update Installed Skills

Refresh installed skills from their recorded sources:

```bash
npx skills update
```

When prompted, choose `Global` to check and update all globally installed personal and third-party skills, including skills from `AtticusZeller/skills`.

Reinstall the current repository-initialization Skill from a local checkout:

```bash
npx skills add . --skill init-repo-agents \
  -g -a codex -a claude-code -a pi -y --full-depth
```

Use the Skill to audit and update an existing repository. Its initializer is only
for a repository without custom `AGENTS.md` or `CLAUDE.md` files.

## External Global Skills

External global skills are referenced through `manifests/global-skills.json`.

The [Stop That Shit](https://github.com/lennney/stop-that-shit) upstream provides two separately installed skills: `stop-that-shit` (scope creep and overengineering control) and `stss` (reduce defensive filler while preserving meaningful qualifications). Both are installed by the external-skills script. The `stop-that-shit` skill is advisory on its own; machine-enforced Guard hooks require the upstream plugin/Guard setup and are **not** installed by this script.

The [no-comments](https://github.com/AtticusZeller/no-comments) repository provides `clean-comments`, which cleans up existing code comments and docstrings. It needs `uv` on the machine and runs the `no-comments` CLI of the same release through `uvx`, so no separate CLI install is needed.

Dry-run the install commands:

```bash
bash scripts/install-global-skills.sh --dry-run
```

Install them:

```bash
bash scripts/install-global-skills.sh
```

The script runs `npx skills add <repo> --skill <skill> -g -a codex -a claude-code -a pi -y` for each manifest entry.

The Skills CLI uses the shared `~/.agents/skills` directory for Codex and Pi; Claude Code gets links in `~/.claude/skills`. The explicit agent flags limit the requested installation targets, but shared skills may also appear in listings for other agents that consume the universal directory, such as GitHub Copilot.

For Context7, it also runs:

```bash
npx ctx7 setup --cli --claude --codex -y
```

If Context7 requires authentication, complete its login flow; no token is stored in this repository.

## OfficeCLI

[OfficeCLI](https://github.com/iOfficeAI/OfficeCLI) is intentionally **not** part
of the manifest or `scripts/install-global-skills.sh`. It ships its own installer
that places the binary and the `officecli` skill together, so the Skills CLI path
would only duplicate it. Install it directly from upstream:

```bash
# macOS / Linux
curl -fsSL https://d.officecli.ai/install.sh | bash

# Windows (PowerShell)
irm https://d.officecli.ai/install.ps1 | iex
```

Then run the upstream one-step setup, which copies the binary onto `PATH` and
registers the skill with every AI coding agent it detects:

```bash
officecli install                      # binary + skills + MCP for all detected agents
officecli install claude               # or target one agent
officecli skills install               # skills only, no MCP
```

Agents can also read the skill body directly from `https://officecli.ai/SKILL.md`
when the binary is missing.

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
