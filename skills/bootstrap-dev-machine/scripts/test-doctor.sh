#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_src="$(cd "${script_dir}/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
unset CLAUDE_CONFIG_DIR XDG_CONFIG_HOME PERSONAL_SKILLS_DIR

fail() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }

# A throwaway repo with this skill, one sibling personal skill and a small manifest.
repo="${tmp_dir}/repo"
mkdir -p "$repo/skills" "$repo/manifests"
cp -r "$skill_src" "$repo/skills/bootstrap-dev-machine"
mkdir -p "$repo/skills/demo"
printf -- '---\nname: demo\ndescription: d\n---\n' >"$repo/skills/demo/SKILL.md"
cat >"$repo/manifests/global-skills.json" <<'EOF'
{"packages": [{"repo": "acme/skills", "skills": ["third", "absent"]}]}
EOF
git -C "$repo" init -q
git -C "$repo" -c user.name=t -c user.email=t@t add -A
git -C "$repo" -c user.name=t -c user.email=t@t commit -qm init
doctor="$repo/skills/bootstrap-dev-machine/scripts/doctor.sh"
assets="$repo/skills/bootstrap-dev-machine/assets"

home="${tmp_dir}/home"
mkdir -p "$home"
export HOME="$home"
run() { bash "$doctor" --repo "$repo" --skip-packages "$@"; }
status_of() { awk -v id="$1" '$3 == id { print $1; exit }' "$tmp_dir/out"; }
expect() {   # id status
  [[ "$(status_of "$1")" == "$2" ]] || { cat "$tmp_dir/out" >&2; fail "$1 expected $2, got $(status_of "$1")"; }
}

# Skills: third installed with the right source, demo installed but stale,
# bootstrap-dev-machine identical, extra unknown skill.
install_skill() {   # name source-dir
  mkdir -p "$home/.agents/skills" "$home/.claude/skills"
  cp -r "$2" "$home/.agents/skills/$1"
  ln -s "../../.agents/skills/$1" "$home/.claude/skills/$1"
}
mkdir -p "$tmp_dir/third"; printf -- '---\nname: third\n---\n' >"$tmp_dir/third/SKILL.md"
install_skill third "$tmp_dir/third"
install_skill demo "$repo/skills/demo"
printf 'local edit\n' >>"$home/.agents/skills/demo/SKILL.md"
install_skill bootstrap-dev-machine "$repo/skills/bootstrap-dev-machine"
install_skill stray "$tmp_dir/third"
printf '{"version":3,"skills":{"third":{"source":"acme/skills"}}}\n' >"$home/.agents/.skill-lock.json"

# Configs.
mkdir -p "$home/.claude" "$home/.config/herdr" "$home/.config/ghostty" "$home/.config/tmux" "$home/.codex"
bash "$repo/skills/bootstrap-dev-machine/scripts/install-claude-statusline.sh" >/dev/null
cp "$assets/herdr-config.toml" "$home/.config/herdr/config.toml"
printf '# my prompt\n' >"$home/.p10k.zsh"
{ printf '# my comment\n\n'; cat "$assets/ghostty-config.ghostty"; printf 'font-size = 99\n'; } \
  >"$home/.config/ghostty/config.ghostty"
{ printf 'upstream = 1\n'; cat "$assets/tmux-defaults.conf"; printf 'mine = 2\n'; } \
  >"$home/.config/tmux/tmux.conf.local"
printf 'echo personal\n' >"$home/.zshrc"
bash "$repo/skills/bootstrap-dev-machine/scripts/install-machine-handoff.sh" --target-home "$home" >/dev/null
# Personal section in the middle of AGENTS.md is allowed.
awk 'NR > 1 && /^## / && !done { print "## My Notes\n\n- mine\n"; done = 1 } { print }' \
  "$home/.codex/AGENTS.md" >"$tmp_dir/a" && mv "$tmp_dir/a" "$home/.codex/AGENTS.md"

snapshot() { (cd "$home" && find . -type f -print0 | sort -z | xargs -0 sha256sum); }
before="$(snapshot)"
if run >"$tmp_dir/out"; then fail "doctor should exit 1 with problems"; fi
[[ "$before" == "$(snapshot)" ]] || fail "report modified the home directory"

expect skill:third OK
expect skill:absent MISSING
expect skill:demo STALE
expect skill:bootstrap-dev-machine OK
grep -q '^EXTRA .*stray' "$tmp_dir/out" || fail "stray not reported as EXTRA"
expect statusline-script OK
expect statusline-setting OK
expect herdr OK
expect p10k DRIFT
expect ghostty OK
expect tmux-local OK
expect zshrc DRIFT
expect codex-agents OK

# Package checks use the current PATH and never install a missing Pi.
mkdir -p "$tmp_dir/bin"
for tool in awk basename bash cat cmp diff dirname git grep head install jq mkdir mktemp mv paste rm uname wc; do
  ln -s "$(command -v "$tool")" "$tmp_dir/bin/$tool"
done
if PATH="$tmp_dir/bin" bash "$doctor" --repo "$repo" >"$tmp_dir/out"; then
  fail "doctor should exit 1 with missing packages"
fi
expect command:pi MISSING
grep -Fq 'curl -fsSL https://pi.dev/install.sh | sh' "$tmp_dir/out" || fail "missing Pi install hint"
printf '#!/bin/bash\n[[ "$1" == --version ]] && echo 1.2.3\n' >"$tmp_dir/bin/pi"
chmod +x "$tmp_dir/bin/pi"
PATH="$tmp_dir/bin" bash "$repo/skills/bootstrap-dev-machine/scripts/check-dev-machine.sh" >"$tmp_dir/out"
grep -Eq '^INFO pi +1\.2\.3$' "$tmp_dir/out" || fail "missing Pi version"
! grep -Fq 'https://pi.dev/install.sh' "$tmp_dir/out" || fail "install hint printed for installed Pi"

# Section edits are drift; --diff names only the changed section.
sed -i 's/^- Prefer uv for Python/- Prefer pip for Python/' "$home/.codex/AGENTS.md"
run >"$tmp_dir/out" || true
expect codex-agents DRIFT
grep -q 'sections: Python$' "$tmp_dir/out" || fail "drift should name only the Python section"
before="$(snapshot)"
run --diff codex-agents >"$tmp_dir/diff"
[[ "$before" == "$(snapshot)" ]] || fail "--diff modified the home directory"
grep -q '^=== Python ===' "$tmp_dir/diff" || fail "diff missing Python section"
! grep -q 'My Notes' "$tmp_dir/diff" || fail "personal section reported as drift"

# A trailing tmux change is fine; a missing repo line is drift.
sed -i '/update-environment/d' "$home/.config/tmux/tmux.conf.local"
run >"$tmp_dir/out" || true
expect tmux-local DRIFT

# Ignore list.
bash "$doctor" --ignore zshrc >/dev/null
run >"$tmp_dir/out" || true
expect zshrc IGNORED

# --sync to local: backup kept, target matches the asset.
bash "$doctor" --repo "$repo" --sync p10k --to local >/dev/null
cmp "$assets/p10k.zsh" "$home/.p10k.zsh"
compgen -G "$home/.p10k.zsh.bak.*" >/dev/null || fail "no p10k backup"
jq '.statusLine.refreshInterval = 5' "$home/.claude/settings.json" >"$tmp_dir/s" && mv "$tmp_dir/s" "$home/.claude/settings.json"
bash "$doctor" --repo "$repo" --sync statusline-setting --to local >/dev/null
[[ "$(jq .statusLine.refreshInterval "$home/.claude/settings.json")" == 15 ]] || fail "statusLine not restored"

# --sync to repo: only the matching asset changes in the checkout.
printf 'custom = true\n' >"$home/.config/herdr/config.toml"
bash "$doctor" --repo "$repo" --sync herdr --to repo >/dev/null
cmp "$home/.config/herdr/config.toml" "$assets/herdr-config.toml"
[[ "$(git -C "$repo" status --short)" == ' M skills/bootstrap-dev-machine/assets/herdr-config.toml' ]] ||
  fail "unexpected repo changes: $(git -C "$repo" status --short)"

# Symlinked targets are never replaced by a copy.
mkdir -p "$home/dotfiles"
printf 'linked = 1\n' >"$home/dotfiles/herdr.toml"
ln -sf "$home/dotfiles/herdr.toml" "$home/.config/herdr/config.toml"
if bash "$doctor" --repo "$repo" --sync herdr --to local 2>/dev/null; then fail "symlink sync should be refused"; fi
[[ -L "$home/.config/herdr/config.toml" && "$(cat "$home/dotfiles/herdr.toml")" == 'linked = 1' ]] || fail "symlink replaced"

# A git worktree counts as a checkout, and --to repo writes into it, not the main repo.
git -C "$repo" -c user.name=t -c user.email=t@t commit -qam herdr
git -C "$repo" worktree add -q "$tmp_dir/wt" -b wt
printf 'wt = 1\n' >"$home/dotfiles/herdr.toml"
bash "$tmp_dir/wt/skills/bootstrap-dev-machine/scripts/doctor.sh" --sync herdr --to repo >/dev/null
[[ -z "$(git -C "$repo" status --short)" ]] || fail "worktree sync wrote into the main checkout"
[[ "$(git -C "$tmp_dir/wt" status --short)" == ' M skills/bootstrap-dev-machine/assets/herdr-config.toml' ]] ||
  fail "worktree sync did not update the worktree"

# Mixed-content items refuse automatic sync.
if bash "$doctor" --repo "$repo" --sync ghostty --to local 2>/dev/null; then fail "ghostty sync should be refused"; fi
if bash "$doctor" --repo "$repo" --sync statusline-setting --to repo 2>/dev/null; then fail "setting to repo should be refused"; fi

# macOS layout: Library ghostty path, zshrc.macos, macOS handoff template, and the
# [OK]/[MISSING]/[MANUAL] package report (stubbed: the real check refuses non-Darwin).
mac="${tmp_dir}/mac"
mkdir -p "$mac/Library/Application Support/com.mitchellh.ghostty"
HOME="$mac" bash "$repo/skills/bootstrap-dev-machine/scripts/install-claude-statusline.sh" >/dev/null
{ cat "$assets/ghostty-config.macos.ghostty"; printf 'font-size = 18\n'; } \
  >"$mac/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
{ cat "$assets/zshrc.macos"; printf 'alias mine=1\n'; } >"$mac/.zshrc"
HOME="$mac" PROXY_URL=disabled bash "$repo/skills/bootstrap-dev-machine/scripts/install-machine-handoff.sh" \
  --target-home "$mac" --platform macos --proxy-url disabled >/dev/null
cat >"$repo/skills/bootstrap-dev-machine/scripts/check-dev-machine-macos.sh" <<'EOF'
echo '[OK] brew: /opt/homebrew/bin/brew'
echo '[MISSING] sbc'
echo '[MANUAL] GitHub CLI login: gh auth login'
exit 1
EOF
HOME="$mac" PROXY_URL=disabled bash "$doctor" --repo "$repo" --platform macos >"$tmp_dir/out" || true
expect ghostty OK
expect zshrc OK
expect codex-agents OK
expect statusline-script OK
expect command:sbc MISSING
expect manual:GitHub WARN
grep -q '^OK  *packages  *1 checks passed' "$tmp_dir/out" || fail "macOS OK count"
printf 'echo hi\n' >"$repo/skills/bootstrap-dev-machine/scripts/check-dev-machine-macos.sh"
printf 'exit 3\n' >>"$repo/skills/bootstrap-dev-machine/scripts/check-dev-machine-macos.sh"
HOME="$mac" bash "$doctor" --repo "$repo" --platform macos >"$tmp_dir/out" || true
expect check:exit WARN
if bash "$doctor" --platform windows 2>/dev/null; then fail "unknown platform accepted"; fi

printf '[PASS] doctor statuses, read-only report, diff, ignore and sync\n'
