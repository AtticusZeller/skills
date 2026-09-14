# Scan Playbook

Measurement commands. All read-only. Run wide, then drill narrow — never `du` the whole tree at
full depth.

## 0. Baseline

```bash
df -h | grep -v tmpfs
du -h -d1 "$HOME" 2>/dev/null | sort -rh | head -30
```

Record this `df`. Every "freed N GB" claim is relative to it.

## 1. System-level sweep — do this before the home scan

The largest consumers are usually outside `$HOME`. Skipping this step on the reference machine
missed 183 GB (103 GB Docker + 80 GB Timeshift).

```bash
# Top level of the root filesystem. Needs sudo for /var, /timeshift, /root.
sudo du -h -d1 / 2>/dev/null | sort -rh | head -20

# The usual suspects, individually
sudo du -h -d1 /var 2>/dev/null | sort -rh | head -12
sudo du -h -d1 /var/lib 2>/dev/null | sort -rh | head -12
du -h -d1 /opt /usr /snap 2>/dev/null | sort -rh | head -15
sudo du -sh /timeshift 2>/dev/null
```

If `sudo -n` fails, say so and report the audit as incomplete rather than omitting these silently.

## 2. Per-subsystem detail

### Docker

```bash
docker system df                       # authoritative. Use these numbers, not image sizes.
docker system df -v                    # per-image / per-volume breakdown
docker images -f dangling=true -q | wc -l
docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
docker volume ls -f dangling=true -q | wc -l
docker image ls --format '{{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}' | grep -v '^<none>'
```

> **Never sum `docker images --format '{{.Size}}'`.** Dangling images share most of their layers, so
> the sum is wildly inflated — on the reference machine 68 dangling images summed to 979 GB while the
> true reclaimable figure was 45 GB. `docker system df` is the only trustworthy source.

### Timeshift / snapshots

```bash
sudo du -h -d2 /timeshift/snapshots 2>/dev/null | sort -rh | head -20
sudo ls -la --time-style=+%Y-%m-%d /timeshift/snapshots/
sudo du -h -d2 /timeshift/snapshots/<newest>/localhost/ 2>/dev/null | sort -rh | head -15
cat /etc/timeshift/timeshift.json
```

Read the `exclude` array. A snapshot that includes `/var/lib/snapd`, `/var/lib/flatpak`,
`/var/lib/docker`, `/var/log`, or `/var/cuda-repo-*` is copying re-downloadable content every run.
On the reference machine this inflated one daily snapshot to 65 GB.

### Package caches

```bash
du -sh ~/.cache/{uv,pip,npm,yarn,pnpm,bun} 2>/dev/null
du -sh ~/.npm/_cacache ~/.npm/_npx 2>/dev/null
du -sh ~/miniforge3/pkgs ~/miniconda3/pkgs 2>/dev/null
du -sh ~/.local/share/pnpm/store ~/.local/share/uv 2>/dev/null
```

### Editors and agents

```bash
du -h -d1 ~/.claude ~/.codex ~/.vscode ~/.vscode-server 2>/dev/null | sort -rh | head -15
ls -d ~/.claude/plugins/cache/*/*/*/ 2>/dev/null      # stale plugin versions, ~470MB each
du -sh ~/.cache/vscode-cpptools ~/.config/Code/CachedExtensionVSIXs 2>/dev/null
ls -la ~/.local/share/claude/versions/                 # old CLI builds, ~200MB each
```

### Application caches

```bash
du -h -d1 ~/.cache 2>/dev/null | sort -rh | head -40
```

Cross-check each against the owning app before listing:

```bash
for n in <name>; do
  r=""
  command -v "$n" >/dev/null 2>&1 && r="bin"
  ls /usr/share/applications/ ~/.local/share/applications/ 2>/dev/null | grep -qi "$n" && r="$r desktop"
  dpkg -l 2>/dev/null | awk '{print $2}' | grep -qi "^${n}" && r="$r dpkg"
  flatpak list --app --columns=application 2>/dev/null | grep -qi "$n" && r="$r flatpak"
  snap list 2>/dev/null | awk '{print $1}' | grep -qi "$n" && r="$r snap"
  printf '%-24s %s\n' "$n" "${r:-ABSENT}"
done
```

`ABSENT` across all five is the signal that a directory is an orphan. Note that `dpkg -l` status `rc`
means *removed, config remains* — that counts as absent.

## 3. Orphan sweep

```bash
# Data directories with no owning application
for d in ~/.config/*/ ~/.local/share/*/ ~/.cache/*/; do
  n=$(basename "$d")
  # ... run the five-signal check above; print when ABSENT
done

# Flatpak data for uninstalled flatpaks
for d in ~/.var/app/*/; do
  n=$(basename "$d")
  flatpak list --app --columns=application 2>/dev/null | grep -qx "$n" \
    || printf 'ORPHAN %8s  %s\n' "$(du -sh "$d" | cut -f1)" "$n"
done
```

## 4. Age and size

```bash
# Files untouched for over a year, aggregated by directory with total bytes
find "$HOME" -xdev -type f ! -newermt "$(date -d '1 year ago' +%F)" \
  -not -path "*/.git/*" -not -path "*/node_modules/*" \
  -not -path "*/site-packages/*" -not -path "*/.venv/*" \
  -printf '%s\t%h\n' 2>/dev/null \
  | awk -F'\t' '{split($2,a,"/"); k=a[1]"/"a[2]"/"a[3]"/"a[4]; s[k]+=$1}
                END {for (k in s) printf "%10.1fM  %s\n", s[k]/1048576, k}' \
  | sort -rn | head -35

# Large files with dates
find "$HOME" -xdev -type f -size +500M -printf '%s\t%TY-%Tm-%Td\t%p\n' 2>/dev/null \
  | sort -rn | head -40 \
  | awk -F'\t' '{printf "%6.1fG  %s  %s\n", $1/1073741824, $2, $3}'

# Rebuildable project artifacts
find "$HOME" -xdev -type d \( -name node_modules -o -name .venv -o -name target \) -prune 2>/dev/null \
  | while read -r d; do printf '%8s  %s  %s\n' "$(du -sh "$d" | cut -f1)" "$(stat -c '%y' "$d" | cut -d' ' -f1)" "$d"; done \
  | sort -rh | head -25
```

## 5. Per-directory recency table

For a candidate list, produce size + mtime together so the plan can be ranked:

```bash
for d in ~/.cache/*/; do
  printf '%-38s %8s  %s\n' "$(basename "$d")" \
    "$(du -sh "$d" 2>/dev/null | cut -f1)" \
    "$(stat -c '%y' "$d" 2>/dev/null | cut -d' ' -f1)"
done | sort -k3
```

## Measurement traps

| Trap | Symptom | Handling |
|---|---|---|
| `atime` under `relatime` | every directory reports today | Use `mtime` only. Never cite `atime`. |
| `du` hardlink dedup | `du -sh A` alone > the `A` line inside `du -d1 parent` | Both are correct. `du` dedups within a single invocation. Say which you are quoting. |
| Docker layer sharing | summing image sizes gives ~10× the truth | Use `docker system df`. |
| Compressed + extracted pairs | `.zst` / `.tar.gz` beside the unpacked tree | Count only the redundant member, not both. |
| Sparse files | `du` << apparent size | Quote `du`, and note it if the pair looks odd. |
| `~/Downloads` re-downloads | `file.tar.gz.1` beside `file.tar.gz` | The `.1` suffix is a duplicate download. |

## Reporting the scan

State the coverage explicitly. If sudo was unavailable for `/var`, `/timeshift`, or `/root`, the
audit is partial — say so instead of presenting a home-only total as the whole picture.
