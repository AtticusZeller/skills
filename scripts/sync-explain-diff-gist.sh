#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
gist_id="a29df1b5f9865506e8952488eac3d524"
gist_url="https://gist.github.com/${gist_id}.git"
check_only=false

if [[ "${1:-}" == "--check" ]]; then
  check_only=true
elif (($#)); then
  printf 'Usage: sync-explain-diff-gist.sh [--check]\n' >&2
  exit 2
fi

revision="$(git ls-remote "$gist_url" HEAD | awk 'NR == 1 { print $1 }')"
[[ "$revision" =~ ^[0-9a-f]{40}$ ]] || {
  printf '[ERROR] Could not resolve the official Explain Diff Gist HEAD\n' >&2
  exit 1
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

for variant in html notion; do
  name="explain-diff-${variant}"
  source_url="https://gist.githubusercontent.com/geoffreylitt/${gist_id}/raw/${revision}/${name}.md"
  destination="${repo_root}/skills/${name}/SKILL.md"
  curl --fail --location --silent --show-error \
    "$source_url" >"${tmp_dir}/${name}.md"
  grep -Fq "name: ${name}" "${tmp_dir}/${name}.md" || {
    printf '[ERROR] Upstream %s has an unexpected skill name\n' "$name" >&2
    exit 1
  }

  if [[ -f "$destination" ]] &&
    cmp -s "${tmp_dir}/${name}.md" "$destination"; then
    printf '[INFO] unchanged %s\n' "$destination"
  elif [[ "$check_only" == true ]]; then
    printf '[ERROR] upstream update available for %s at %s\n' \
      "$name" "$revision" >&2
    exit 1
  else
    install -m 0644 "${tmp_dir}/${name}.md" "$destination"
    printf '[INFO] mirrored %s at %s\n' "$name" "$revision"
  fi
done
