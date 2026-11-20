#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
installer="${script_dir}/install-claude-statusline.sh"
asset="${script_dir}/../assets/claude-statusline.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
unset CLAUDE_CONFIG_DIR

fail() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }

# Fresh home with a space in its path: dry run writes nothing.
home="${tmp_dir}/fresh home"
mkdir -p "$home"
bash "$installer" --target-home "$home" --dry-run >/dev/null
[[ -z "$(ls -A "$home")" ]] || fail "dry run wrote files"

# First install: script matches the asset, settings holds only statusLine.
bash "$installer" --target-home "$home" >/dev/null
cmp "$asset" "$home/.claude/statusline-command.sh"
[[ -x "$home/.claude/statusline-command.sh" ]] || fail "script not executable"
[[ "$(jq -r 'keys | join(",")' "$home/.claude/settings.json")" == statusLine ]] || fail "unexpected settings keys"
cmd="$(jq -r '.statusLine.command' "$home/.claude/settings.json")"
[[ "$(jq -r '.statusLine.refreshInterval' "$home/.claude/settings.json")" == 15 ]] || fail "refreshInterval"

# The configured command renders two lines from a minimal payload.
payload='{"model":{"display_name":"Test"},"workspace":{"current_dir":"/tmp/x"},"context_window":{"used_percentage":10,"context_window_size":200000,"current_usage":{"input_tokens":1000}}}'
lines="$(printf '%s' "$payload" | COLUMNS=120 bash -c "$cmd" | wc -l)"
[[ "$lines" -ge 1 ]] || fail "statusline rendered nothing"

# macOS runs it with bash 3.2 when no Homebrew bash exists: no $'\U...' escapes,
# and GNU-only stat calls need a BSD fallback.
! grep -qF "\$'\\U" "$asset" || fail "asset uses \\U escapes (bash 4.2+)"
! grep -n 'stat -c' "$asset" | grep -vq 'stat -f' || fail "stat -c without BSD fallback"
# A C-locale environment still measures glyph widths in characters.
c_out="$(printf '%s' "$payload" | env -i PATH="$PATH" COLUMNS=60 bash "$asset")"
[[ -n "$c_out" && "$c_out" == "$(printf '%s' "$payload" | COLUMNS=60 bash "$asset")" ]] ||
  fail "C-locale run differs from the UTF-8 run"

# Rerun is idempotent and never touches local edits.
cp "$home/.claude/settings.json" "$tmp_dir/before.json"
bash "$installer" --target-home "$home" >/dev/null
cmp -s "$tmp_dir/before.json" "$home/.claude/settings.json" || fail "rerun changed settings"
printf '# local\n' >"$home/.claude/statusline-command.sh"
jq '.statusLine.command = "custom"' "$home/.claude/settings.json" >"$tmp_dir/s" && mv "$tmp_dir/s" "$home/.claude/settings.json"
bash "$installer" --target-home "$home" >/dev/null
[[ "$(cat "$home/.claude/statusline-command.sh")" == '# local' ]] || fail "script overwritten"
[[ "$(jq -r .statusLine.command "$home/.claude/settings.json")" == custom ]] || fail "statusLine overwritten"

# Existing personal settings: only statusLine is added, with a backup.
home2="${tmp_dir}/personal"
mkdir -p "$home2/.claude"
printf '{"model":"opus","env":{"A":"1"},"permissions":{"allow":["Bash(ls)"]}}\n' >"$home2/.claude/settings.json"
chmod 0600 "$home2/.claude/settings.json"
original="$(jq -S . "$home2/.claude/settings.json")"
bash "$installer" --target-home "$home2" >/dev/null
[[ "$(jq -S 'del(.statusLine)' "$home2/.claude/settings.json")" == "$original" ]] || fail "personal keys changed"
[[ "$(ls -l "$home2/.claude/settings.json" | cut -c1-10)" == -rw------- ]] || fail "settings mode changed"
compgen -G "$home2/.claude/settings.json.bak.*" >/dev/null || fail "no backup"
[[ "$(jq -S . "$home2"/.claude/settings.json.bak.*)" == "$original" ]] || fail "backup differs"

# CLAUDE_CONFIG_DIR redirects both targets.
home3="${tmp_dir}/cfg"
mkdir -p "$home3"
CLAUDE_CONFIG_DIR="$home3/alt" bash "$installer" --target-home "$home3" >/dev/null
cmp "$asset" "$home3/alt/statusline-command.sh"
jq -e '.statusLine.command | contains("/alt/statusline-command.sh")' "$home3/alt/settings.json" >/dev/null || fail "config dir command"

printf '[PASS] Claude statusline fidelity, dry run, idempotency, merge and preservation\n'
