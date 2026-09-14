#!/usr/bin/env bash
# disk-triage.sh — read-only disk usage triage.
#
# This script NEVER deletes, moves, or modifies anything. It only reads.
# It is safe to run as an unprivileged user; sudo-requiring sections degrade
# gracefully and are marked INCOMPLETE in the report rather than skipped silently.
#
# Usage:
#   disk-triage.sh [-o REPORT.md] [-t ROOT] [-h]
#
#   -o FILE   write the report to FILE (default: stdout)
#   -t ROOT   triage home root (default: $HOME)
#   -h        show this help

set -uo pipefail

HOME_ROOT="${HOME}"
OUT=""
AGE_DAYS=365
BIG_MB=500

usage() { sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

while getopts ":o:t:h" opt; do
  case "$opt" in
    o) OUT="$OPTARG" ;;
    t) HOME_ROOT="$OPTARG" ;;
    h) usage ;;
    *) echo "Unknown option: -$OPTARG" >&2; usage ;;
  esac
done

emit() { printf '%s\n' "$*"; }
hdr()  { emit ""; emit "$*"; emit ""; }
sub()  { emit "### $*"; emit ""; }

have_sudo() { sudo -n true 2>/dev/null; }

# Sudo helper. Note: never chain this with `||` — `du` exits non-zero on any
# unreadable subdirectory even under sudo, which would run the fallback too and
# emit every row twice. Pick the branch once, explicitly.
SUDO_OK=true
have_sudo || SUDO_OK=false
srun() {
  if $SUDO_OK; then sudo -n "$@" 2>/dev/null; else return 1; fi
}

# du -h -d1, privileged when possible, chosen once rather than via `||`.
du1() {
  if $SUDO_OK; then sudo -n du -h -d1 "$@" 2>/dev/null
  else du -h -d1 "$@" 2>/dev/null; fi
}

# du -sh, same contract.
dus() {
  if $SUDO_OK; then sudo -n du -sh "$@" 2>/dev/null
  else du -sh "$@" 2>/dev/null; fi
}

# Render a du listing as a markdown table of size | path.
table() {
  awk -F'\t' '{printf "| %s | `%s` |\n", $1, $2}'
}

cut_size() { du -sh "$1" 2>/dev/null | cut -f1; }
cut_date() { stat -c '%y' "$1" 2>/dev/null | cut -d' ' -f1; }

# ── Body assembled into a variable so -o can redirect cleanly ────────────────
report() {

hdr "# Disk Triage Report"
emit "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
emit "Home root: \`${HOME_ROOT}\`"
emit "Age threshold: ${AGE_DAYS} days · Size threshold: ${BIG_MB} MB"
$SUDO_OK || emit ""
$SUDO_OK || emit "> **WARNING: sudo unavailable.** \`/var\`, \`/timeshift\` and \`/root\` are NOT covered."
$SUDO_OK || emit "> This report is PARTIAL. Re-run with sudo for the full picture."

# ── 1. Baseline ──────────────────────────────────────────────────────────────
hdr "## 1. Baseline"
emit '```'
df -h 2>/dev/null | grep -v -E 'tmpfs|udev|efivarfs'
emit '```'

# ── 2. Filesystem sweep ──────────────────────────────────────────────────────
hdr "## 2. Filesystem sweep"
emit "Top level of \`/\`. The largest consumers are frequently outside \`\$HOME\`."
emit ""
emit "| Size | Path |"
emit "|---|---|"
du1 / | sort -rh | head -20 | table
if ! $SUDO_OK; then
  emit ""
  emit "_Unprivileged — \`/var\`, \`/timeshift\`, \`/root\` may be under-reported._"
fi

# ── 3. Subsystem drill-down ──────────────────────────────────────────────────
hdr "## 3. Subsystem drill-down"
for sysdir in /var /var/lib /var/log /opt /usr /snap; do
  s=$(cut_size "$sysdir") || continue
  [ -z "$s" ] && continue
  sub "\`${sysdir}\` — ${s}"
  emit "| Size | Subdirectory | Last modified |"
  emit "|---|---|---|"
  du1 "$sysdir" | sort -rh | head -10 \
    | while IFS=$'\t' read -r sz p; do
        [ "$p" = "$sysdir" ] && continue
        printf '| %s | `%s` | %s |\n' "$sz" "$p" "$(cut_date "$p")"
      done
done

# ── 4. Docker ────────────────────────────────────────────────────────────────
hdr "## 4. Docker"
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  emit "Authoritative figures. **Never sum per-image sizes** — dangling images share layers and"
  emit "the sum over-reports by roughly 10x."
  emit ""
  emit '```'
  docker system df 2>/dev/null
  emit '```'
  sub "Dangling images"
  emit "Count: $(docker images -f dangling=true -q 2>/dev/null | wc -l)"
  sub "Tagged images"
  emit "| Repository:Tag | Size | Created |"
  emit "|---|---|---|"
  docker image ls --format '{{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}' 2>/dev/null \
    | grep -v '^<none>' | awk -F'\t' '{printf "| `%s` | %s | %s |\n", $1, $2, $3}'
  sub "Containers"
  emit "| Name | Image | Status |"
  emit "|---|---|---|"
  docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}' 2>/dev/null \
    | awk -F'\t' '{printf "| %s | `%s` | %s |\n", $1, $2, $3}'
  sub "Unused volumes"
  emit "Count: $(docker volume ls -f dangling=true -q 2>/dev/null | wc -l) · Size: $(cut_size /var/lib/docker/volumes 2>/dev/null || echo unknown)"
else
  emit "_Docker not available or not permitted._"
fi

# ── 5. Timeshift ─────────────────────────────────────────────────────────────
hdr "## 5. Timeshift snapshots"
if [ -d /timeshift/snapshots ]; then
  emit "Total: $(cut_size /timeshift)"
  emit ""
  emit "| Size | Snapshot | Created |"
  emit "|---|---|---|"
  dus /timeshift/snapshots/*/ | sort -rh | while IFS=$'\t' read -r sz p; do
    printf '| %s | `%s` | %s |\n' "$sz" "$(basename "$p")" "$(cut_date "$p")"
  done
  sub "Config"
  if $SUDO_OK; then
    srun cat /etc/timeshift/timeshift.json | head -40
  else
    emit "_needs sudo_"
  fi
  emit ""
  emit "**Check the \`exclude\` array.** If \`/var/lib/snapd\`, \`/var/lib/flatpak\`,"
  emit "\`/var/lib/docker\`, \`/var/log\` or vendored apt repos are absent from it, every future"
  emit "snapshot will duplicate re-downloadable content."
else
  emit "_No timeshift directory._"
fi

# ── 6. Home layout ───────────────────────────────────────────────────────────
hdr "## 6. Home layout"
emit "| Size | Path | Last modified |"
emit "|---|---|---|"
du -h -d1 "$HOME_ROOT" 2>/dev/null | sort -rh | head -30 \
  | while IFS=$'\t' read -r sz p; do
      printf '| %s | `%s` | %s |\n' "$sz" "$(basename "$p")" "$(cut_date "$p")"
    done

# ── 7. Caches by recency ─────────────────────────────────────────────────────
hdr "## 7. Cache directories by recency"
emit "Sorted oldest-first. Rank by age, not size alone."
emit ""
emit "| Last modified | Size | Path |"
emit "|---|---|---|"
for base in "$HOME_ROOT/.cache"; do
  [ -d "$base" ] || continue
  for d in "$base"/*/; do
    [ -e "$d" ] || continue
    printf '%s\t%s\t%s\n' "$(cut_date "$d")" "$(cut_size "$d")" "$d"
  done
done | sort | head -40 \
  | while IFS=$'\t' read -r dt sz p; do printf '| %s | %s | `%s` |\n' "$dt" "$sz" "$p"; done

# ── 8. Orphan candidates ─────────────────────────────────────────────────────
hdr "## 8. Orphan candidates"
emit "Directories whose owning application shows no \`bin\` / \`desktop\` / \`dpkg\` / \`flatpak\` /"
emit "\`snap\` signal. **A name match is not proof** — verify before acting."
emit ""
emit "| Size | Path | Last modified |"
emit "|---|---|---|"

owned_by() {
  local n="$1" r=""
  command -v "$n" >/dev/null 2>&1 && r="y"
  [ -z "$r" ] && ls /usr/share/applications/ "$HOME_ROOT/.local/share/applications/" 2>/dev/null \
    | grep -qi "$n" && r="y"
  [ -z "$r" ] && dpkg -l 2>/dev/null | awk '{print $2}' | grep -qi "^${n}" && r="y"
  [ -z "$r" ] && flatpak list --app --columns=application 2>/dev/null | grep -qi "$n" && r="y"
  [ -z "$r" ] && snap list 2>/dev/null | awk '{print $1}' | grep -qi "$n" && r="y"
  [ -n "$r" ]
}

for base in "$HOME_ROOT/.config" "$HOME_ROOT/.local/share" "$HOME_ROOT/.cache"; do
  [ -d "$base" ] || continue
  for d in "$base"/*/; do
    n=$(basename "$d")
    case "$n" in
      dconf|gtk-*|fontconfig|enchant|menus|autostart|systemd|pulse|goa-1.0|mime|icons|applications|backgrounds|fonts|Trash|keyrings) continue ;;
    esac
    owned_by "$n" || printf '%s\t%s\t%s\n' "$(cut_size "$d")" "$d" "$(cut_date "$d")"
  done
done | sort -rh | head -50 \
  | while IFS=$'\t' read -r sz p dt; do printf '| %s | `%s` | %s |\n' "$sz" "$p" "$dt"; done

sub "Flatpak data for uninstalled flatpaks"
found=0
if [ -d "$HOME_ROOT/.var/app" ]; then
  for d in "$HOME_ROOT/.var/app"/*/; do
    [ -e "$d" ] || continue
    n=$(basename "$d")
    if ! flatpak list --app --columns=application 2>/dev/null | grep -qx "$n"; then
      found=1
      printf -- '- %s `%s` (%s)\n' "$(cut_size "$d")" "$d" "$(cut_date "$d")"
    fi
  done
fi
[ "$found" = 0 ] && emit "_none_"

# ── 9. Age buckets ───────────────────────────────────────────────────────────
hdr "## 9. Stale data by age"
emit "Based on **mtime**. \`atime\` is not used: under ext4 \`relatime\` it is unreliable and any"
emit "scan refreshes it."
emit ""
emit "| Bucket | Files | Total size |"
emit "|---|---|---|"
for spec in "730:over 2 years" "365:1-2 years" "180:6-12 months"; do
  days="${spec%%:*}"; label="${spec#*:}"
  cutoff=$(date -d "${days} days ago" +%F 2>/dev/null) || continue
  res=$(find "$HOME_ROOT" -xdev -type f ! -newermt "$cutoff" \
          -not -path "*/.git/*" -not -path "*/node_modules/*" \
          -not -path "*/site-packages/*" -not -path "*/.venv/*" \
          -printf '%s\n' 2>/dev/null \
        | awk -v d="$days" '{n++; s+=$1} END {printf "%d\t%.1f", n, s/1073741824}')
  n="${res%%$'\t'*}"; g="${res##*$'\t'}"
  printf '| %s | %s | %.1f GB |\n' "$label" "${n:-0}" "${g:-0}"
done

sub "Files not modified in ${AGE_DAYS}+ days, aggregated by directory"
cutoff=$(date -d "${AGE_DAYS} days ago" +%F 2>/dev/null)
find "$HOME_ROOT" -xdev -type f ! -newermt "$cutoff" \
  -not -path "*/.git/*" -not -path "*/node_modules/*" \
  -not -path "*/site-packages/*" -not -path "*/.venv/*" \
  -not -path "*/Trash/*" \
  -printf '%s\t%h\n' 2>/dev/null \
  | awk -F'\t' '{n=split($2,a,"/"); k=a[1]"/"a[2]"/"a[3]"/"a[4]; s[k]+=$1}
                 END {for (k in s) printf "%10.1fM\t%s\n", s[k]/1048576, k}' \
  | sort -rn | head -30 \
  | awk -F'\t' '{printf "| %s | `%s` |\n", $1, $2}' \
  | { emit "| Size | Directory |"; emit "|---|---|"; cat; }

# ── 10. Large files ──────────────────────────────────────────────────────────
hdr "## 10. Large files (over ${BIG_MB} MB)"
emit "| Size | Last modified | Path |"
emit "|---|---|---|"
find "$HOME_ROOT" -xdev -type f -size "+${BIG_MB}M" -printf '%s\t%TY-%Tm-%Td\t%p\n' 2>/dev/null \
  | sort -rn | head -40 \
  | awk -F'\t' '{printf "| %.1f GB | %s | `%s` |\n", $1/1073741824, $2, $3}'

# ── 11. Rebuildable artifacts ────────────────────────────────────────────────
hdr "## 11. Rebuildable project artifacts"
emit "| Size | Last modified | Path |"
emit "|---|---|---|"
find "$HOME_ROOT" -xdev -type d \( -name node_modules -o -name .venv -o -name venv \) -prune 2>/dev/null \
  | while read -r d; do
      printf '%s\t%s\t%s\n' "$(cut_size "$d")" "$(cut_date "$d")" "$d"
    done | sort -rh | head -30 \
  | while IFS=$'\t' read -r sz dt p; do printf '| %s | %s | `%s` |\n' "$sz" "$dt" "$p"; done

# ── 12. Handoff ──────────────────────────────────────────────────────────────
hdr "## 12. Next steps"
emit "1. Classify every finding with \`references/classification.md\`."
emit "2. Verify each orphan claim with an independent signal before listing it."
emit "3. Check the never-delete list against the candidate set."
emit "4. Emit a tiered plan of literal paths. Do not execute it."
emit ""
emit "Re-run after cleanup to measure:"
emit '```bash'
emit "df -h /"
emit '```'
}

if [ -n "$OUT" ]; then
  report | tee "$OUT" >/dev/null
  echo "Report written to: $OUT"
else
  report
fi
