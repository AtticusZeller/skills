---
name: claude-memory-to-codex
description: Mirror Claude Code auto-memory (~/.claude/projects/*/memory/*.md) into Codex memory as ad-hoc notes so Codex's own consolidation absorbs them. Use when the user wants Claude memories migrated, synced, or refreshed into Codex, asks which Claude memories Codex is missing, or wants stale migrated notes cleaned up.
---

# Claude Memory to Codex

Codex rewrites `~/.codex/memories/MEMORY.md` and `memory_summary.md` itself, so never edit them.
The supported input is the `ad_hoc` memory extension: every Markdown note under
`$CODEX_HOME/memories/extensions/ad_hoc/notes/` is treated as authoritative data and folded in on
the next memory consolidation (new and edited notes both show up in its workspace diff).

`scripts/sync-claude-memory` turns each Claude memory file (except `MEMORY.md`) into one note
`claude-memory--<project>--<file>.md`, carrying origin, `applies_to: cwd=<project path>`
(home-level memories are global), kind, last edit date, and the original body. It is idempotent:
unchanged sources are not rewritten, edited sources overwrite their note.

```bash
scripts/sync-claude-memory --dry-run   # preview
scripts/sync-claude-memory             # write notes
scripts/sync-claude-memory --prune     # also delete notes whose source is gone or excluded
```

- Project cwd comes from the newest session transcript's `cwd`, else from decoding the project
  directory name against the filesystem. Projects whose directory no longer exists are skipped
  unless `--include-missing` is passed.
- Exclusions live outside the repo in `~/.config/claude-memory-to-codex/exclude.txt`, one
  `<encoded-project-dir>` or `<encoded-project-dir>/<file>.md` per line; `#` starts a comment.
  Exclude Claude-only facts (Claude plugins, Claude plan files) that mean nothing to Codex.
- Orphaned notes are only listed by default; `--prune` deletes only notes carrying the sync marker.
- Notes are never named with a leading timestamp, so Codex's age-based extension pruning skips them.
- `--memory-root` targets another memory root (e.g. `~/.codex/memories_v2`). The script refuses to
  run if `extensions/ad_hoc/instructions.md` is missing (memories disabled or Codex never ran).

Recovery: if a Codex upgrade moves the notes directory (upstream source has used
`extensions/ad_hoc/resources/`), check the installed binary's prompt
(`strings "$(readlink -f "$(command -v codex)")" | rg 'extensions/ad_hoc/'`) and update
`notes_dir` in the script. Consolidation is model-driven: verify migrated facts with
`rg '\[ad-hoc note\]' ~/.codex/memories/MEMORY.md` after Codex has run.

Regression check: `bash scripts/test-sync-claude-memory.sh`.
