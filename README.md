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
area-level `plan.md`, `log.md`, and `overview.md` files. Reusable commands live
in `docs/cmd.md`, never in a repository-root command notebook.

The initializer is create-only and refuses to replace custom rule files. Existing
repositories are updated through an inspected, user-confirmed patch rather than a
managed block. Common Skills are recorded with explicit triggers and are never
chained into an automatic lifecycle.

Install the plan-driven feature development skill globally:

```bash
npx skills add AtticusZeller/skills --skill develop-feature -g -a codex -a claude-code -a cursor -y --full-depth
```

This skill agrees a plan with the human first, then lets that plan govern
implementation, an external code review, static checks, documentation sync, and
closeout into `docs/<area>/log.md`.

Install the disk cleanup skill globally:

```bash
npx skills add AtticusZeller/skills --skill disk-cleanup -g -a codex -a claude-code -a cursor -y --full-depth
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

Install the delegated worker skill globally:

```bash
npx skills add AtticusZeller/skills --skill delegate-worker -g -a codex -a claude-code -a cursor -y --full-depth
```

This skill runs a separate Claude Code process on a third-party provider
configured in cc-switch, such as DeepSeek, and treats it as a worker. A native
subagent cannot do this because it always inherits its caller's provider. The
calling agent writes the brief, chooses a permission profile, and decides whether
to start a new worker, resume one, or fork one. It verifies the worker's report
before relaying it. `scripts/delegate-worker.sh` keeps each worker's session,
briefs, and results under `~/.local/state/delegate-worker/`. By default a
worker inherits the caller's `CLAUDE.md`, plugins, skills, MCP servers, and
hooks. A repository `AGENTS.md` that Claude Code would not discover is passed to
it explicitly, and `--bare` creates a clean-room worker instead. A stub-based regression
test covers session flags, permissions, contract fidelity, and failure exit
codes.

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

## Serena

[Serena](https://github.com/oraios/serena) is a global MCP tool rather than a
Skill. It gives coding agents language-server-backed symbol search, reference
lookup, rename, and symbol-level editing, so it belongs in the development-machine
baseline alongside the agent CLIs.

Install and initialize the released package with uv:

```bash
uv tool install -p 3.13 serena-agent
serena init
```

Register Serena globally for both local agents:

```bash
serena setup codex
serena setup claude-code
```

The generated MCP entries start Serena from the agent's current project and use
the client-specific context. Restart the agents after setup and verify registration
with `/mcp`.

Keep Serena's project metadata outside repositories, retain automatic language
detection, disable its dashboard and memory tools, and keep the normal interactive
symbol-editing workflow by applying the global baseline:

```bash
bash skills/bootstrap-dev-machine/scripts/configure-serena.sh
```

This updates only the following global settings in `~/.serena/serena_config.yml`
and preserves Serena's other defaults and registered projects:

```yaml
language_backend: LSP
web_dashboard: false
web_dashboard_open_on_launch: false
base_modes:
  - interactive
  - editing
  - no-memories
project_serena_folder_location: "/home/<user>/.serena/projects/$projectFolderName/.serena"
```

With `--project-from-cwd`, Serena finds the current repository, detects its
languages, and selects the corresponding language servers automatically. A
project-specific `language_servers` override is only needed when auto-detection
is wrong or the project requires a non-default server. `planning` and `one-shot`
remain opt-in modes: planning removes write tools, while one-shot changes the
interaction policy without restricting editing tools.

Update Serena later with:

```bash
uv tool upgrade serena-agent
```

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
