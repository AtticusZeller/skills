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

This skill provides an idempotent one-shot installer for the full machine baseline, including public machine handoff docs, a server `.zshrc`, ripgrep (`rg`) for agent-friendly code and document search, Oh My Zsh, Powerlevel10k, shell plugins, CUDA, uv, Miniforge/conda/mamba, NVM, proxy variables, and non-systemd sing-box helpers.

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

This skill creates a human-owned collaboration baseline: the human decides intent,
scope, architecture, interfaces, task decomposition, and acceptance; the agent
implements and verifies. Tasks use `Change + Observable Evidence`, `CLAUDE.md`
imports the authoritative `AGENTS.md`, and project context is organized under
area-level `plan.md`, `log.md`, and `overview.md` files.

The initializer is create-only and refuses to replace custom rule files. Existing
repositories are updated through an inspected, user-confirmed patch rather than a
managed block. Common Skills are recorded with explicit triggers and are never
chained into an automatic lifecycle.

Install Geoffrey Litt's mirrored Explain Diff skills globally:

```bash
npx skills add AtticusZeller/skills \
  --skill explain-diff-html explain-diff-notion \
  -g -a codex claude-code cursor -y --full-depth
```

The skill bodies are direct mirrors of Geoffrey Litt's official Explain Diff Gist:
`https://gist.github.com/geoffreylitt/a29df1b5f9865506e8952488eac3d524`.
The HTML variant is available when a user explicitly requests a rich diff
explanation; the Notion variant is available when Notion tools are connected.

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

Reinstall the current repository-initialization Skill from a local checkout:

```bash
npx skills add . --skill init-repo-agents \
  -g -a codex -a claude-code -a cursor -y --full-depth
```

Use the Skill to audit and update an existing repository. Its initializer is only
for a repository without custom `AGENTS.md` or `CLAUDE.md` files.

Synchronize both mirrored skills from the official Gist:

```bash
bash scripts/sync-explain-diff-gist.sh
```

The weekly GitHub Actions workflow performs the same synchronization and commits
changed upstream skill bodies directly to this public repository.

## External Global Skills

External global skills are normally referenced through
`manifests/global-skills.json`. Geoffrey Litt's two Explain Diff variants are the
explicit mirrored exception described above.

Dry-run the install commands:

```bash
bash scripts/install-global-skills.sh --dry-run
```

Install them:

```bash
bash scripts/install-global-skills.sh
```

The script runs `npx skills add <repo> --skill <skill> -g -a codex -a claude-code -a cursor -y` for each manifest entry.

The Skills CLI uses the shared `~/.agents/skills` directory for Codex and Cursor. The explicit agent flags limit the requested installation targets, but shared skills may also appear in listings for other agents that consume the universal directory, such as GitHub Copilot.

For Context7, it also runs:

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
