#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
installer="$script_dir/install-pi-config.sh"
assets="$script_dir/../assets/pi"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
export HOME="$tmp/test home"
unset PI_CODING_AGENT_DIR
mkdir -p "$HOME/.codex"
printf 'shared instructions\n' > "$HOME/.codex/AGENTS.md"
agent="$HOME/.pi/agent"

bash "$installer" --dry-run >/dev/null
[[ ! -e "$HOME/.pi" ]]
bash "$installer" >/dev/null
for file in settings.json APPEND_SYSTEM.md extensions/compact-bash.ts extensions/pi-tool-display/config.json extensions/tokyo-footer/index.ts; do
  cmp "$assets/$file" "$agent/$file"
done
[[ -L "$agent/AGENTS.md" ]]
cmp "$HOME/.codex/AGENTS.md" "$agent/AGENTS.md"
[[ ! -e "$agent/extensions/tokyo-footer/test.mjs" ]]
[[ ! -e "$agent/auth.json" && ! -e "$agent/sessions" ]]
bash "$installer" >/dev/null
cmp "$assets/settings.json" "$agent/settings.json"
if compgen -G "$agent/settings.json.bak.*" >/dev/null; then
  echo '[FAIL] Rerunning on a fresh config created a backup' >&2
  exit 1
fi

export PI_CODING_AGENT_DIR="$tmp/alternate dir"
agent="$PI_CODING_AGENT_DIR"
mkdir -p "$agent/extensions/tokyo-footer"
printf 'local footer\n' > "$agent/extensions/tokyo-footer/index.ts"
printf 'local instructions\n' > "$agent/AGENTS.md"
printf 'local prompt\n' > "$agent/APPEND_SYSTEM.md"
printf '%s\n' '{"defaultModel":"custom","compaction":{"reserveTokens":12345,"enabled":false},"packages":["npm:custom"],"unrelated":{"keep":true}}' > "$agent/settings.json"
cp "$agent/settings.json" "$tmp/before.json"
bash "$installer" --dry-run >/dev/null
cmp "$tmp/before.json" "$agent/settings.json"
[[ ! -e "$agent/extensions/compact-bash.ts" ]]
bash "$installer" >/dev/null
[[ $(cat "$agent/extensions/tokyo-footer/index.ts") == 'local footer' ]]
[[ $(cat "$agent/AGENTS.md") == 'local instructions' ]]
[[ $(cat "$agent/APPEND_SYSTEM.md") == 'local prompt' ]]
jq -e --slurpfile defaults "$assets/settings.json" --slurpfile before "$tmp/before.json" '. == ($defaults[0] * $before[0])' "$agent/settings.json" >/dev/null
cmp "$tmp/before.json" "$agent"/settings.json.bak.*
cp "$agent/settings.json" "$tmp/merged.json"
bash "$installer" >/dev/null
cmp "$tmp/merged.json" "$agent/settings.json"
cmp "$tmp/before.json" "$agent"/settings.json.bak.*

echo '[PASS] Pi config dry run, fidelity, idempotency, local-setting preservation and backup'
