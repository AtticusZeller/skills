# Repository Agent Guide

This repository publishes AtticusZeller's personal agent skills. Keep it installable with:

```bash
npx skills add AtticusZeller/skills --list --full-depth
```

## Repository Rules

- Personal skills live under `skills/<skill-name>/`.
- Every skill must contain a valid `SKILL.md` with `name` and `description` frontmatter.
- Skill names use lowercase letters, digits, and hyphens only.
- Do not copy third-party skill source into this repository.
- Third-party global skills are listed in `manifests/global-skills.json` and installed by `scripts/install-global-skills.sh`.
- Do not commit tokens, PATs, private subscriptions, SSH keys, node credentials, API keys, or machine-private config.
- Do not add README files inside individual skill folders; put human-facing repo docs in the root `README.md`.
- Validate before commit and push:

```bash
bash scripts/validate-skills.sh
npx skills add . --list --full-depth
bash scripts/install-global-skills.sh --dry-run
```

## Publishing

- GitHub target: `AtticusZeller/skills`.
- Visibility: public.
- Use `main` as the default branch.
- Before publishing, confirm `git status --short` only shows intended repo files.
- After pushing, verify remote install discovery:

```bash
npx skills add AtticusZeller/skills --list --full-depth
```

## Skill Maintenance

- Keep `SKILL.md` concise; move detailed workflows into `references/`.
- Use `scripts/` only for deterministic helpers that are useful to run directly.
- Give repeatable multi-step setup workflows one idempotent executable entry point; keep Markdown focused on inputs, boundaries, and recovery.
- Fixed or long generated files must live in `assets/` or explicit templates and be deployed by a deterministic script. Never instruct an agent to reconstruct, summarize, or copy executable output from a Markdown fence.
- Any skill with fixed templates or deployable assets must include an executable helper and a regression check that proves template fidelity and idempotency.
- Keep generated or local-machine artifacts out of the repo.
- If adding an external skill dependency, update `manifests/global-skills.json` instead of vendoring it.
