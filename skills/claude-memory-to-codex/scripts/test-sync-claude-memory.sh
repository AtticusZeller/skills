#!/usr/bin/env bash
# Regression check for sync-claude-memory: note format, idempotency, update, exclude, prune.
set -euo pipefail

script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/sync-claude-memory"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

home="$tmp/home"
proj_path="$home/work/my-repo"
mkdir -p "$proj_path"
enc="$(printf '%s' "$proj_path" | tr '/' '-')"
gone="$(printf '%s' "$home/work/deleted" | tr '/' '-')"
projects="$home/.claude/projects"
mkdir -p "$projects/$enc/memory" "$projects/$gone/memory"
root="$home/.codex/memories"
mkdir -p "$root/extensions/ad_hoc"
echo "# Ad-hoc notes" >"$root/extensions/ad_hoc/instructions.md"

cat >"$projects/$enc/memory/rule-a.md" <<'EOF'
---
name: rule-a
description: "first rule"
metadata:
  type: feedback
---

Body A.
EOF
echo "index" >"$projects/$enc/memory/MEMORY.md"
printf -- '---\nname: old\ntype: project\n---\nOld.\n' >"$projects/$gone/memory/old.md"

run() { HOME="$home" CODEX_HOME="$home/.codex" "$script" --exclude-file "$home/exclude.txt" "$@"; }
notes="$root/extensions/ad_hoc/notes"
note="$notes/claude-memory--work-my-repo--rule-a.md"

# Dry run writes nothing.
run --dry-run >/dev/null
[[ ! -e "$notes" ]] || fail "dry run created notes dir"

# First run: one note from the existing project, missing project skipped, MEMORY.md ignored.
out="$(run)"
[[ -f "$note" ]] || fail "note not created"
[[ "$(ls "$notes" | wc -l)" -eq 1 ]] || fail "unexpected note count: $(ls "$notes")"
grep -q "project dir missing" <<<"$out" || fail "missing project not reported"
grep -qx "# rule-a" "$note" || fail "title"
grep -qx -- "- applies_to: cwd=$proj_path" "$note" || fail "applies_to"
grep -qx -- "- kind: feedback" "$note" || fail "kind"
grep -qx -- "- summary: first rule" "$note" || fail "summary"
grep -qx "Body A." "$note" || fail "body"
grep -q "^<!-- synced-from-claude-memory: ~/.claude/projects/$enc/memory/rule-a.md sha256=" "$note" || fail "marker"
if grep -q '^name:' "$note"; then fail "frontmatter leaked"; fi

# Second run is a no-op.
before="$(stat -c %Y.%s "$note")"
out="$(run --json)"
grep -q '"created": \[\]' <<<"$out" || fail "second run created"
grep -q '"updated": \[\]' <<<"$out" || fail "second run updated"
[[ "$(stat -c %Y.%s "$note")" == "$before" ]] || fail "note rewritten"

# Source edit updates the note.
sed -i 's/Body A./Body A2./' "$projects/$enc/memory/rule-a.md"
out="$(run --json)"
grep -q 'rule-a.md"' <<<"$(sed -n '/"updated"/,/]/p' <<<"$out")" || fail "update not reported"
grep -qx "Body A2." "$note" || fail "update not written"

# --include-missing syncs the gone project with a placeholder cwd.
run --include-missing >/dev/null
gone_note="$(ls "$notes" | grep -- '--old.md$')" || fail "include-missing note"
grep -q "project directory no longer exists" "$notes/$gone_note" || fail "missing cwd placeholder"

# Excluded / deleted sources become orphans; only --prune deletes, and only marked notes.
echo "$gone   # stale project" >"$home/exclude.txt"
echo "unmanaged" >"$notes/claude-memory--hand-written.md"
out="$(run)"
grep -q "orphaned" <<<"$out" || fail "orphan not reported"
[[ -f "$notes/$gone_note" ]] || fail "orphan deleted without --prune"
run --prune >/dev/null
[[ ! -e "$notes/$gone_note" ]] || fail "prune kept orphan"
[[ -f "$notes/claude-memory--hand-written.md" ]] || fail "prune removed unmarked note"
[[ -f "$note" ]] || fail "prune removed live note"

# Refuses to run when Codex memories are not initialized.
rm "$root/extensions/ad_hoc/instructions.md"
if run >/dev/null 2>&1; then fail "ran without instructions.md"; fi

echo "sync-claude-memory: all checks passed"
