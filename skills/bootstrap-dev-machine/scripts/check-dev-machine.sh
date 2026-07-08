#!/usr/bin/env bash
set -u

ok=0
warn=0

check_cmd() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    printf 'OK   command %-12s %s\n' "$name" "$(command -v "$name")"
  else
    printf 'WARN command %-12s missing\n' "$name"
    warn=$((warn + 1))
  fi
}

check_path() {
  local path="$1"
  if [[ -e "$path" ]]; then
    printf 'OK   path    %s\n' "$path"
  else
    printf 'WARN path    %s missing\n' "$path"
    warn=$((warn + 1))
  fi
}

check_version() {
  local label="$1"
  shift
  printf 'INFO %-14s ' "$label"
  "$@" 2>/dev/null | head -n 1 || true
}

echo "== Commands =="
for cmd in git curl uv python3 sbc claude gh hf cc-switch nvitop wandb zsh tmux; do
  check_cmd "$cmd"
done

if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
  # shellcheck disable=SC1091
  . "$HOME/.nvm/nvm.sh"
  check_cmd node
  check_cmd npm
  check_cmd npx
else
  printf 'WARN nvm     %s missing\n' "$HOME/.nvm/nvm.sh"
  warn=$((warn + 1))
fi

echo
echo "== Versions =="
check_version "uv" uv --version
check_version "python3" python3 --version
check_version "sbc" sbc version
check_version "claude" claude --version
check_version "gh" gh --version
check_version "hf" hf --version
check_version "cc-switch" cc-switch --version
if command -v node >/dev/null 2>&1; then
  check_version "node" node -v
  check_version "npm" npm -v
fi

echo
echo "== Paths =="
check_path "$HOME/.config/sing-box/config.json"
check_path "$HOME/.local/bin/sbc-start"
check_path "$HOME/.local/bin/sbc-stop"
check_path "$HOME/.local/bin/sbc-status"
check_path "$HOME/AGENTS.md"
check_path "$HOME/README.md"
check_path "$HOME/.codex/AGENTS.md"
check_path "$HOME/.agents/skills"
check_path "$HOME/.claude/rules/context7.md"

echo
echo "== Proxy =="
git_http="$(git config --global --get http.proxy || true)"
git_https="$(git config --global --get https.proxy || true)"
printf 'INFO git http.proxy  %s\n' "${git_http:-<unset>}"
printf 'INFO git https.proxy %s\n' "${git_https:-<unset>}"
printf 'INFO http_proxy      %s\n' "${http_proxy:-<unset>}"
printf 'INFO https_proxy     %s\n' "${https_proxy:-<unset>}"

echo
if [[ "$warn" -eq 0 ]]; then
  echo "OK bootstrap checks passed"
  exit "$ok"
fi

echo "WARN bootstrap checks completed with ${warn} warning(s)"
exit 0
