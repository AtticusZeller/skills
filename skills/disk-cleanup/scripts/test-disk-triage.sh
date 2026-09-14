#!/usr/bin/env bash
# Regression test for disk-triage.sh.
#
# Verifies the two things that matter about this skill's executable:
#   1. it is genuinely read-only, and
#   2. it produces a structurally complete report on a controlled fixture.
#
# Usage: bash test-disk-triage.sh

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="$here/disk-triage.sh"

fails=0
pass() { printf '  PASS  %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }

echo "test-disk-triage.sh"
echo

# ── 1. Exists and is executable ──────────────────────────────────────────────
[ -f "$script" ]      && pass "script exists"        || fail "script missing at $script"
[ -x "$script" ]      && pass "script is executable" || fail "script is not executable"
bash -n "$script" 2>/dev/null && pass "syntax valid" || fail "syntax error"

# ── 2. Read-only guarantee ───────────────────────────────────────────────────
# The skill's whole contract is that it never deletes. Guard that mechanically
# rather than by review, so a future edit cannot quietly break it.
destructive='(^|[^[:alnum:]_])(rm|rmdir|unlink|shred|truncate|mv)[[:space:]]'
if grep -nEq "$destructive" "$script"; then
  fail "script contains a destructive command:"
  grep -nE "$destructive" "$script" | sed 's/^/         /'
else
  pass "no destructive commands (rm/rmdir/unlink/shred/truncate/mv)"
fi

# A stray redirection to an absolute or $HOME path would let it write outside
# any tmpdir. Writing to its own -o target is fine and is matched separately.
if grep -nE '>>?[[:space:]]*("?\$HOME|/etc|/usr|/var)' "$script" >/dev/null; then
  fail "script redirects output into a system path:"
  grep -nE '>>?[[:space:]]*("?\$HOME|/etc|/usr|/var)' "$script" | sed 's/^/         /'
else
  pass "no writes into system paths"
fi

# ── 3. Fixture run ───────────────────────────────────────────────────────────
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

root="$tmp/home"
mkdir -p "$root/.cache/stale-cache" \
         "$root/.config/totallyabsentapp" \
         "$root/.local/share/totallyabsentapp" \
         "$root/proj/node_modules" \
         "$root/.config/realapp"
head -c 1048576 /dev/zero > "$root/big.bin" 2>/dev/null
touch -d '2023-01-01' "$root/.cache/stale-cache" \
                      "$root/.config/totallyabsentapp" \
                      "$root/big.bin"
# An app that IS present on the system, to prove no false positive.
touch -d '2023-01-01' "$root/.config/bash"

out="$tmp/report.md"
if timeout 300 bash "$script" -t "$root" -o "$out" >/dev/null 2>&1; then
  pass "fixture run exits 0"
else
  fail "fixture run exited non-zero"
fi

[ -s "$out" ] && pass "report written to -o target" || fail "report not written"

# ── 4. Structural completeness ───────────────────────────────────────────────
for n in 1 2 3 4 5 6 7 8 9 10 11 12; do
  grep -q "^## ${n}\. " "$out" 2>/dev/null \
    && pass "section ${n} present" \
    || fail "section ${n} missing"
done

# ── 5. Orphan detection is correct in both directions ────────────────────────
grep -q 'totallyabsentapp' "$out" \
  && pass "flags an orphan directory" \
  || fail "missed an orphan directory"

# `bash` is installed, so $root/.config/bash must NOT be reported as an orphan.
if sed -n '/## 8\./,/## 9\./p' "$out" | grep -q '/\.config/bash/'; then
  fail "false positive: reported an installed app's directory as an orphan"
else
  pass "no false positive on an installed app"
fi

# ── 6. Recency ranking ───────────────────────────────────────────────────────
# The 2023 fixture must land in the "over 2 years" bucket.
if sed -n '/## 9\./,/## 10\./p' "$out" | grep -qE '^\| over 2 years \| [1-9]'; then
  pass "places stale files in the over-2-years bucket"
else
  fail "age bucketing did not count the 2023 fixture"
fi

# ── 7. Usage contract ────────────────────────────────────────────────────────
bash "$script" -h 2>/dev/null | grep -q 'NEVER deletes' \
  && pass "-h states the read-only contract" \
  || fail "-h does not state the read-only contract"

echo
if [ "$fails" -eq 0 ]; then
  echo "All checks passed."
  exit 0
fi
echo "$fails check(s) failed."
exit 1
