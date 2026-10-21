# Windows Bootstrap

The Windows entry point is `../scripts/bootstrap-dev-machine.ps1`. It runs in Windows PowerShell 5.1 or PowerShell 7 and is safe to rerun. Run it from a non-elevated PowerShell because Scoop refuses to install as administrator:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\bootstrap-dev-machine.ps1 -DryRun
powershell -ExecutionPolicy Bypass -File scripts\bootstrap-dev-machine.ps1
```

## Inputs

- `PROXY_URL` (default `http://127.0.0.1:7890`), `BOOTSTRAP_PYTHON_VERSION` (default `3.12`), `BOOTSTRAP_NODE_VERSION` (default `24`), `PERSONAL_SKILLS_DIR` (default `~/skills`).
- `-NoProxy`, `-SkipPackages` (Scoop), `-SkipApps` (winget), `-SkipSkills`, `-SkipContext7`.
- `assets/winget-apps.txt` lists the GUI applications to install. Edit the list rather than the script.

## Phases

1. Proxy: sets proxy variables for the installer process only, plus the Git and Scoop proxy config. It never writes persistent user proxy variables.
2. Scoop command-line tools: installs Scoop when missing, then git and ripgrep (required) and gh, jq, bat, fd, fzf, ffmpeg (optional). A command that already exists from any source is reused.
3. winget GUI applications from `assets/winget-apps.txt`; IDs that are already installed are skipped.
4. uv (official installer), uv Python, and the sing-box-cli, nvitop, and wandb uv tools.
5. Node: reuses an existing Node with the requested major version. Otherwise it installs fnm through Scoop, installs and defaults that version, and prepends fnm's `aliases\default` to the user PATH so non-interactive agent shells find Node without profile hooks.
6. Claude Code and the Hugging Face CLI through their official `install.ps1`, each run in a child PowerShell.
7. Agent skills: `npx skills add`, then `scripts/install-global-skills.sh` through Git Bash.
8. Machine handoff: `install-machine-handoff.sh --platform windows` through Git Bash, which renders the Windows templates.
9. `check-dev-machine.ps1` validation and the consolidated manual follow-up list.

Git Bash is located from `git --exec-path`, never from `bash` on PATH, because `System32\bash.exe` is WSL.

## Not Installed on Windows

Conda/Miniforge, zsh/Oh My Zsh, Oh my tmux, the `sbc-start/stop/status` helpers, and the DSW persistent-storage prompt. Manage sing-box with `sbc config` and `sbc service` from an elevated PowerShell, or `sbc run`.

## Recovery

- `Scoop must be installed from a non-elevated PowerShell`: reopen PowerShell without administrator rights.
- Scripts blocked after setup: the summary asks for `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`. The installer never changes execution policy itself.
- Wrong Node version after fnm setup: another Node directory precedes fnm's default alias on PATH. Machine PATH entries always precede user PATH entries.
- Python CLIs crashing with `UnicodeEncodeError` in legacy consoles: the scripts set `PYTHONUTF8=1`; set it in your own session too.
- Repository checkouts must keep LF line endings; the root `.gitattributes` enforces this even with `core.autocrlf=true`.
