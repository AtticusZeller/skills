# Classification, Decision Profile, and Reclaim Targets

## Deciding Tier

Classify each candidate by two independent questions.

**Is it the only copy?**
- Reproducible from a network source or a build command → lower tier.
- Unique output of human or model work → T2 or T3, regardless of size.

**Is the owning process alive?**
- App present and its data modified recently → not a candidate, whatever its size.
- App absent by all five signals → candidate, but see the never-delete list first.

Only after both: apply age. A 40 GB toolchain untouched for 17 months outranks a 60 GB toolchain
touched last week.

## Tiers

### T0 — propose directly

Regenerated automatically; deleting costs only the time to rebuild.

- Package manager caches: `uv`, `pip`, `npm` (`_cacache`, `_npx`), `yarn`, `pnpm` store, `bun`, `go-build`
- Conda package caches: `<prefix>/pkgs`
- Desktop trash: `~/.local/share/Trash/*`
- Editor index caches: `~/.cache/vscode-cpptools`, `~/.config/Code/CachedExtensionVSIXs`
- Browser **HTTP** caches under `~/.cache/` (never `~/.config/`)
- Shader and texture caches: `~/.cache/nvidia`, `~/.cache/ov`
- Build caches: Docker build cache, `Toolchain/vcpkg/{buildtrees,packages}`
- Orphaned `.tmp*` directories inside a package cache — these indicate an interrupted operation and
  are never reclaimed by the tool itself
- Tool-owned upload staging: `~/.local/share/wandb/artifacts/staging`

### T1 — propose, human runs

Re-downloadable or rebuildable at a known cost.

- Superseded tool versions: `~/.local/share/claude/versions/*` (keep the one `readlink -f $(command -v claude)` resolves to), old plugin versions under `~/.claude/plugins/cache/*/*/*/`
- Installed `.deb` / `.AppImage` / `.tar.gz` installers in `~/Downloads`, and their duplicate
  `*.tar.gz.1` re-downloads
- Extracted-and-installed archives where the install tree still exists
- Redundant Python runtimes under `~/.local/share/uv/python/` not targeted by a `cpython-3.x` symlink
- Unused Node versions under `~/.nvm/versions/node/`
- Project virtualenvs and `node_modules` for projects with no recent commits
- Docker: dangling images, stopped containers, unused volumes
- Timeshift snapshots beyond the most recent one or two
- Vendored apt repo directories after install: `/var/cuda-repo-*`, `/var/cudnn-local-repo-*`
- Disabled snap revisions: `snap list --all | awk '/disabled/{print $1, $3}'`

### T2 — ask per item

Could be the only copy. Present the evidence and let the human decide.

- **Whole toolchain installations** that a shell config no longer references (`miniconda3` after a
  migration to `miniforge3`) — but enumerate the environments inside first, and offer to export
  their specs before deletion
- **Data directories of absent applications** that may hold exports, saves, or local databases
- Application data directories for apps still installed but long unused
- Large media and model caches: Hugging Face hub, `~/Videos`, `~/Downloads` media
- Container images with a tag but no running container for months
- Git repositories with large unpacked object stores (`git gc` rather than delete)
- Anything under `~/Documents` outside a named cache

### T3 — never propose

Not a tier to be argued down. Full list below.

## Decision Profile

This profile was established by explicit human choice, not inferred. Do not re-litigate it each run.

**Rank by recency first, size second.** The owner's stated priority is "long time unused". A large
item that is still in use is not a candidate.

**Be aggressive with large, unused, reproducible toolchains.** When offered a conservative and an
aggressive option for a 38 GB conda installation and an 11 GB VM image bundle, the owner chose full
deletion both times. Offer the aggressive option with its rebuild cost stated.

**Be conservative with personal data.** For a 3.6 GB WeChat data directory, the owner chose to clear
only the `cache` subtree and keep `db_storage` and received files. Never fold a data directory into a
cache command because the directory name contains both.

**Keep anything currently in use.** Directories belonging to live applications were explicitly
retained even when large — a 445 MB cache for an actively-used reference manager, and several
installed-then-forgotten utilities. Always run the five-signal check before listing.

**Show commands; the human executes.** The owner runs deletions personally. Produce literal,
copy-pasteable commands grouped by tier so execution can stop between tiers. Do not run deletions.

**sudo is acceptable when evidenced.** System-level targets (`/var`, `/timeshift`, snap revisions)
were acted on once the evidence was shown. Label which commands need sudo.

## Never Delete

Report these as explicitly excluded rather than silently omitting them — the human needs to know the
audit considered them.

| Category | Paths | Why |
|---|---|---|
| Browser profiles | `~/.config/{google-chrome,chromium,BraveSoftware,*}/**/Default` | Bookmarks, saved passwords, sessions. The HTTP cache is in `~/.cache/` — target only that. |
| Chat databases | `~/Documents/xwechat_files/*/db_storage`, `~/.config/QQ/*/nt_db` | Message history. Not reconstructible. |
| Received files | `~/Documents/xwechat_files/*/msg` | Attachments other people sent. |
| Credentials | `~/.ssh`, `~/.gnupg`, `~/.git-credentials`, `~/.netrc`, `~/.aws`, `~/.config/gh` | Access loss is unrecoverable. |
| Agent session history | `~/.claude/projects`, `~/.codex/sessions`, `~/.codex/archived_sessions` | Conversation records. |
| Reference libraries | `~/Zotero`, `~/.zotero` | Research corpus, often years of curation. |
| Mail | `~/.local/share/{evolution,thunderbird}`, `~/Mail` | Local-only mail stores. |
| Password stores | `~/.local/share/keyrings`, `~/.password-store` | |
| Obsidian vaults | Any directory containing `.obsidian/` — attachments included | Note graphs and their media. |
| License state | `~/.config/*/license*`, `~/.local/share/JetBrains/**/eval` | |

When a never-delete directory has a genuinely safe subtree, name the subtree explicitly and keep the
command's target to that subtree only. Never issue a parent-directory `rm` and describe it as
"cache only".

## Notes on Specific Targets

**Docker.** Repeated rebuilds of one project accumulate dozens of 1.4 GB dangling layers. `docker
image prune` without `-a` removes only `<none>` images; with `-a` it also removes tagged images that
no container currently uses. Prefer the bare form unless the human confirms the tagged ones are
disposable.

**Timeshift.** The default config does not exclude `/var/lib/snapd`, `/var/lib/flatpak`,
`/var/lib/docker`, `/var/log`, or vendored apt repos. Each daily snapshot then duplicates tens of GB
of re-downloadable content. Adding those to the `exclude` array is usually worth more than deleting
snapshots, because it caps every future snapshot. Note that `/home` is excluded by default.

**Conda migrations.** When a shell config points at `miniforge3` but `miniconda3` still exists,
miniconda3 is dead weight — but its `envs/` may hold work. Export specs first:

```bash
for e in <env names>; do
  <prefix>/bin/conda env export -n "$e" > "$HOME/conda-env-backup/$e.yml"
done
```

Then remove `<prefix>/` and drop its lines from `~/.conda/environments.txt`, or `conda env list`
reports nonexistent paths forever.

**Extracted/compressed pairs.** `rootfs.vhdx` at 8.6 GB beside `rootfs.vhdx.zst` at 2.2 GB is one
image stored twice. Deleting the compressed member is the zero-cost move.

**TensorRT and vendored SDKs.** A shell config that exports `<SDK>_ROOT`, adds it to `PATH`, or sets
`LD_LIBRARY_PATH` means the tree is live. Never propose the whole directory. Within it, static
libraries (`libnvinfer_static.a`) and other-platform binaries (`*_win.so`) are safe targets.
