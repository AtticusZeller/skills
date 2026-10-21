#Requires -Version 5.1
<#
.SYNOPSIS
Idempotent one-shot installer for the Windows development-machine baseline.

.DESCRIPTION
Command-line tools come from Scoop, GUI applications from winget
(assets/winget-apps.txt). Installs uv/Python, sing-box-cli, Node through fnm
when no matching Node exists, Claude Code, the Hugging Face CLI, agent skills,
and the shared machine handoff. Conda, zsh, and tmux are not installed on Windows.

Environment:
  PROXY_URL                  Proxy URL (default: http://127.0.0.1:7890)
  BOOTSTRAP_PYTHON_VERSION   uv-managed Python version (default: 3.12)
  BOOTSTRAP_NODE_VERSION     Default Node major version (default: 24)
  PERSONAL_SKILLS_DIR        Skills repository checkout (default: ~/skills)
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$NoProxy,
    [switch]$SkipPackages,
    [switch]$SkipApps,
    [switch]$SkipSkills,
    [switch]$SkipContext7,
    [switch]$Help
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if ($Help) {
    @'
Usage: bootstrap-dev-machine.ps1 [options]

Options:
  -DryRun          Print commands without changing the machine
  -NoProxy         Do not configure proxy settings
  -SkipPackages    Skip Scoop command-line packages
  -SkipApps        Skip winget GUI applications (assets/winget-apps.txt)
  -SkipSkills      Skip personal and external agent skill installation
  -SkipContext7    Install skills without running Context7 setup
  -Help            Show this help

Environment:
  PROXY_URL, BOOTSTRAP_PYTHON_VERSION, BOOTSTRAP_NODE_VERSION, PERSONAL_SKILLS_DIR
'@ | Write-Host
    exit 0
}

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    Write-Host '[ERROR] This installer is for Windows; use bootstrap-dev-machine.sh on Linux.'
    exit 2
}

function Get-Setting([string]$Name, [string]$Default) {
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ($value) { return $value }
    return $Default
}

$ScriptDir = $PSScriptRoot
$AssetDir = Join-Path (Split-Path $ScriptDir -Parent) 'assets'
$UseProxy = -not $NoProxy
$ProxyUrl = Get-Setting 'PROXY_URL' 'http://127.0.0.1:7890'
$PythonVersion = Get-Setting 'BOOTSTRAP_PYTHON_VERSION' '3.12'
$NodeVersion = Get-Setting 'BOOTSTRAP_NODE_VERSION' '24'
$LocalBin = Join-Path $HOME '.local\bin'
$PowerShellExe = (Get-Process -Id $PID).Path
$RunnableExtensions = @('.exe', '.com', '.cmd', '.bat', '.ps1')
# Python CLIs such as sbc print emoji; keep them from crashing in cp1252 consoles.
$env:PYTHONUTF8 = '1'

if ($PythonVersion -notmatch '^\d+(\.\d+)?$') {
    Write-Host "[ERROR] Invalid BOOTSTRAP_PYTHON_VERSION: $PythonVersion"; exit 2
}
if ($NodeVersion -notmatch '^\d+$') {
    Write-Host "[ERROR] Invalid BOOTSTRAP_NODE_VERSION: $NodeVersion"; exit 2
}
if ($UseProxy -and -not [Uri]::IsWellFormedUriString($ProxyUrl, [UriKind]::Absolute)) {
    Write-Host "[ERROR] Invalid PROXY_URL: $ProxyUrl"; exit 2
}

$script:Warnings = 0
$script:CurrentPhase = 'startup'
$script:ManualActions = New-Object System.Collections.Generic.List[string]
$script:GitBash = $null

function Write-Info([string]$Message) { Write-Host "[INFO] $Message" }

function Write-Warning2([string]$Message) {
    $script:Warnings++
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Add-Manual([string]$Message) { $script:ManualActions.Add($Message) }

function Start-Phase([string]$Name) {
    $script:CurrentPhase = $Name
    Write-Host ''
    Write-Host "== $Name =="
}

# Ignores extensionless files on PATH (for example agent hook shims), which
# Windows cannot execute.
function Find-Command([string]$Name) {
    return Get-Command $Name -CommandType Application, ExternalScript -All -ErrorAction SilentlyContinue |
        Where-Object { $RunnableExtensions -contains [IO.Path]::GetExtension($_.Source).ToLowerInvariant() } |
        Select-Object -First 1
}

function Test-Command([string]$Name) {
    return [bool](Find-Command $Name)
}

function Format-Command([string]$File, [string[]]$Arguments) {
    $parts = @($File) + $Arguments | ForEach-Object {
        if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
    }
    return ($parts -join ' ')
}

# Runs a native command; returns $true on success. Output goes to the host so
# it never leaks into function return values.
function Invoke-Native {
    param(
        [Parameter(Mandatory)][string]$File,
        [string[]]$Arguments = @(),
        [switch]$AllowFailure
    )
    if ($DryRun) {
        Write-Host "[DRY-RUN] $(Format-Command $File $Arguments)"
        return $true
    }
    $command = $File
    if (-not [IO.Path]::IsPathRooted($File)) {
        $resolved = Find-Command $File
        if (-not $resolved) { throw "Command not found: $File" }
        $command = $resolved.Source
    }
    & $command @Arguments | Out-Host
    if ($LASTEXITCODE -ne 0) {
        if ($AllowFailure) { return $false }
        throw "Command failed with exit code $($LASTEXITCODE): $(Format-Command $File $Arguments)"
    }
    return $true
}

# Runs an official `irm <url> | iex` installer in a child PowerShell so that
# installer side effects such as `exit` cannot end this script.
function Invoke-RemoteInstaller([string]$Url) {
    $command = '[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072; '
    if ($UseProxy) {
        $command += "[Net.WebRequest]::DefaultWebProxy = New-Object Net.WebProxy('$ProxyUrl'); "
    }
    $command += "Invoke-RestMethod '$Url' | Invoke-Expression"
    $null = Invoke-Native $PowerShellExe @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $command)
}

function Update-SessionPath {
    $seen = @{}
    $entries = @($LocalBin) + ($env:Path -split ';') +
        ([Environment]::GetEnvironmentVariable('Path', 'User') -split ';') +
        ([Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';')
    $result = foreach ($entry in $entries) {
        if (-not $entry) { continue }
        $key = $entry.TrimEnd('\').ToLowerInvariant()
        if (-not $seen.ContainsKey($key)) { $seen[$key] = $true; $entry }
    }
    $env:Path = $result -join ';'
}

function Send-EnvironmentChange {
    if (-not ('BootstrapDevMachine.Native' -as [type])) {
        Add-Type -Namespace BootstrapDevMachine -Name Native -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@
    }
    $result = [UIntPtr]::Zero
    $null = [BootstrapDevMachine.Native]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$result)
}

# Prepends a directory to the user PATH, preserving unexpanded %VARIABLES%.
function Add-UserPath([string]$Directory) {
    $key = Get-Item 'HKCU:\Environment'
    $raw = [string]$key.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
    $entries = @($raw -split ';' | Where-Object { $_ })
    $wanted = $Directory.TrimEnd('\')
    foreach ($entry in $entries) {
        if ([Environment]::ExpandEnvironmentVariables($entry).TrimEnd('\') -ieq $wanted) {
            Write-Info "User PATH already contains $Directory"
            return
        }
    }
    if ($DryRun) {
        Write-Host "[DRY-RUN] prepend $Directory to the user PATH"
        return
    }
    $value = (@($Directory) + $entries) -join ';'
    New-ItemProperty -Path 'HKCU:\Environment' -Name Path -Value $value -PropertyType ExpandString -Force | Out-Null
    Send-EnvironmentChange
    Write-Info "Prepended $Directory to the user PATH"
}

function Test-Elevated {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-GitBash {
    if (-not (Test-Command 'git')) { return $null }
    # git --exec-path points at <git root>\mingw64\libexec\git-core for both
    # Git for Windows and Scoop installs; never fall back to WSL's bash.exe.
    $execPath = (& (Find-Command git).Source --exec-path | Select-Object -First 1).Trim()
    $root = Split-Path (Split-Path (Split-Path $execPath -Parent) -Parent) -Parent
    foreach ($candidate in @('bin\bash.exe', 'usr\bin\bash.exe')) {
        $bash = Join-Path $root $candidate
        if (Test-Path $bash) { return $bash }
    }
    return $null
}

function ConvertTo-PosixPath([string]$Path) { return ($Path -replace '\\', '/') }

function Invoke-GitBashScript([string]$Script, [string[]]$Arguments, [switch]$AllowFailure, [switch]$SelfDryRun) {
    if (-not $script:GitBash) { $script:GitBash = Get-GitBash }
    $scriptPath = ConvertTo-PosixPath $Script
    if (-not $script:GitBash) {
        if ($DryRun) {
            Write-Host "[DRY-RUN] <git-bash> $(Format-Command $scriptPath $Arguments)"
            return $true
        }
        throw 'Git Bash was not found; install Git first'
    }
    $allArgs = @($scriptPath) + $Arguments
    if ($SelfDryRun -and $DryRun) {
        # The script implements its own --dry-run; let it report its plan.
        & $script:GitBash @allArgs | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Dry run failed: $scriptPath" }
        return $true
    }
    return (Invoke-Native $script:GitBash $allArgs -AllowFailure:$AllowFailure)
}

function Set-ProxyConfig {
    if (-not $UseProxy) { return }
    $authority = ([Uri]$ProxyUrl).Authority
    if (Test-Command 'git') {
        $null = Invoke-Native 'git' @('config', '--global', 'http.proxy', $ProxyUrl)
        $null = Invoke-Native 'git' @('config', '--global', 'https.proxy', $ProxyUrl)
    }
    if (Test-Command 'scoop') {
        $null = Invoke-Native 'scoop' @('config', 'proxy', $authority)
    }
}

function Initialize-Proxy {
    Start-Phase 'Proxy'
    if (-not $UseProxy) {
        Write-Info 'Proxy configuration skipped'
        return
    }
    # Process-only variables; persistent proxy settings stay Git and Scoop config.
    $env:HTTP_PROXY = $ProxyUrl
    $env:HTTPS_PROXY = $ProxyUrl
    $env:http_proxy = $ProxyUrl
    $env:https_proxy = $ProxyUrl
    if (-not $env:NO_PROXY) { $env:NO_PROXY = 'localhost,127.0.0.1' }
    $env:no_proxy = $env:NO_PROXY
    [Net.WebRequest]::DefaultWebProxy = New-Object Net.WebProxy($ProxyUrl)
    Set-ProxyConfig
    Write-Info 'Process, Git, and Scoop proxy settings configured'
}

function Install-ScoopPackages {
    Start-Phase 'Scoop command-line packages'
    if ($SkipPackages) {
        Write-Info 'Scoop packages skipped'
        return
    }

    if (-not (Test-Command 'scoop')) {
        if (Test-Elevated) {
            throw 'Scoop must be installed from a non-elevated PowerShell; rerun without administrator rights'
        }
        Invoke-RemoteInstaller 'https://get.scoop.sh'
        Update-SessionPath
        if (-not $DryRun -and -not (Test-Command 'scoop')) {
            throw 'Scoop installation completed but scoop is not on PATH'
        }
        if ($UseProxy) {
            $null = Invoke-Native 'scoop' @('config', 'proxy', ([Uri]$ProxyUrl).Authority)
        }
    } else {
        Write-Info 'scoop already installed'
    }

    # package => command; an existing command from any source is reused.
    $required = [ordered]@{ git = 'git'; ripgrep = 'rg' }
    $optional = [ordered]@{ gh = 'gh'; jq = 'jq'; bat = 'bat'; fd = 'fd'; fzf = 'fzf'; ffmpeg = 'ffmpeg' }
    foreach ($package in $required.Keys) {
        if (Test-Command $required[$package]) {
            Write-Info "$($required[$package]) already available"
            continue
        }
        $null = Invoke-Native 'scoop' @('install', $package)
        Update-SessionPath
    }
    foreach ($package in $optional.Keys) {
        if (Test-Command $optional[$package]) {
            Write-Info "$($optional[$package]) already available"
            continue
        }
        if (-not (Invoke-Native 'scoop' @('install', $package) -AllowFailure)) {
            Write-Warning2 "Optional package unavailable: $package"
        }
    }
    Update-SessionPath
    Set-ProxyConfig
}

function Install-WingetApps {
    Start-Phase 'winget GUI applications'
    if ($SkipApps) {
        Write-Info 'winget applications skipped'
        return
    }
    $listFile = Join-Path $AssetDir 'winget-apps.txt'
    if (-not (Test-Path $listFile)) { throw "Missing asset: $listFile" }
    if (-not (Test-Command 'winget')) {
        Write-Warning2 'winget is not available'
        Add-Manual 'Install App Installer (winget) from the Microsoft Store, then rerun with -SkipPackages'
        return
    }
    $ids = Get-Content $listFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') }
    foreach ($id in $ids) {
        & (Find-Command winget).Source list --id $id --exact --accept-source-agreements --disable-interactivity *> $null
        if ($LASTEXITCODE -eq 0) {
            Write-Info "$id already installed"
            continue
        }
        $installed = Invoke-Native 'winget' @(
            'install', '--id', $id, '--exact', '--source', 'winget', '--silent',
            '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity'
        ) -AllowFailure
        if (-not $installed) {
            Write-Warning2 "winget could not install $id"
            Add-Manual "Install $id with winget or remove it from assets/winget-apps.txt"
        }
    }
}

function Install-UvTool([string]$Command, [string]$Package) {
    if (Test-Command $Command) {
        Write-Info "$Command already installed"
        return
    }
    $saved = @{ UV_DEFAULT_INDEX = $env:UV_DEFAULT_INDEX; PIP_INDEX_URL = $env:PIP_INDEX_URL }
    try {
        Remove-Item Env:UV_DEFAULT_INDEX, Env:PIP_INDEX_URL -ErrorAction SilentlyContinue
        $null = Invoke-Native 'uv' @('tool', 'install', '--python', $PythonVersion,
            '--default-index', 'https://pypi.org/simple', $Package)
    } finally {
        foreach ($name in $saved.Keys) {
            if ($null -ne $saved[$name]) { Set-Item "Env:$name" $saved[$name] }
        }
    }
}

function Install-PythonTools {
    Start-Phase 'uv, Python, and Python CLIs'
    Update-SessionPath
    if (-not (Test-Command 'uv')) {
        Invoke-RemoteInstaller 'https://astral.sh/uv/install.ps1'
        Update-SessionPath
        if (-not $DryRun -and -not (Test-Command 'uv')) {
            throw 'uv installation completed but uv is not on PATH'
        }
    } else {
        Write-Info 'uv already installed'
    }
    $null = Invoke-Native 'uv' @('python', 'install', $PythonVersion)
    Install-UvTool 'sbc' 'sing-box-cli'
    Install-UvTool 'nvitop' 'nvitop'
    Install-UvTool 'wandb' 'wandb'
    Add-Manual 'Configure sing-box with sbc config, then run sbc service from an elevated PowerShell (or sbc run)'
}

function Get-NodeMajor {
    if (-not (Test-Command 'node')) { return $null }
    $version = (& (Find-Command node).Source -v 2>$null | Select-Object -First 1)
    if ($version -match '^v(\d+)\.') { return $Matches[1] }
    return $null
}

function Install-Node {
    Start-Phase 'Node'
    $current = Get-NodeMajor
    if ($current -eq $NodeVersion) {
        Write-Info "Reusing Node $NodeVersion from $((Find-Command node).Source)"
        return
    }
    if ($current) { Write-Info "Found Node $current; installing Node $NodeVersion with fnm" }

    if (-not (Test-Command 'fnm')) {
        if (-not (Test-Command 'scoop') -and -not $DryRun) {
            Write-Warning2 'fnm and scoop are unavailable'
            Add-Manual "Install Node $NodeVersion (scoop install fnm, then fnm install $NodeVersion)"
            return
        }
        $null = Invoke-Native 'scoop' @('install', 'fnm')
        Update-SessionPath
    }
    $null = Invoke-Native 'fnm' @('install', $NodeVersion)
    $null = Invoke-Native 'fnm' @('default', $NodeVersion)

    $fnmDir = Join-Path $env:APPDATA 'fnm'
    if (-not $DryRun) {
        $fnmEnv = (& (Find-Command fnm).Source env --json | Out-String) | ConvertFrom-Json
        if ($fnmEnv.FNM_DIR) { $fnmDir = $fnmEnv.FNM_DIR }
    }
    # The default alias on the user PATH makes Node visible to non-interactive
    # agent shells without PowerShell or bash profile hooks.
    $defaultAlias = Join-Path $fnmDir 'aliases\default'
    Add-UserPath $defaultAlias
    $env:Path = "$defaultAlias;$env:Path"

    if (-not $DryRun -and (Get-NodeMajor) -ne $NodeVersion) {
        Write-Warning2 "node on PATH is not Node $NodeVersion"
        Add-Manual "Remove other Node installations that precede $defaultAlias on PATH"
    }
}

function Install-DeveloperClis {
    Start-Phase 'Developer CLIs'
    if (-not (Test-Command 'claude')) {
        Invoke-RemoteInstaller 'https://claude.ai/install.ps1'
    } else {
        Write-Info 'claude already installed'
    }
    if (-not (Test-Command 'hf')) {
        Invoke-RemoteInstaller 'https://hf.co/cli/install.ps1'
    } else {
        Write-Info 'hf already installed'
    }
    Update-SessionPath

    if (-not (Test-Command 'gh')) {
        Write-Warning2 'gh was not installed by Scoop'
        Add-Manual 'Install GitHub CLI with scoop install gh'
    }
    if (-not (Test-Command 'codex')) {
        Write-Warning2 'codex is not installed automatically'
        Add-Manual 'Install Codex with the supported entry point for Windows'
    }
    if (-not (Test-Command 'cc-switch')) {
        Write-Warning2 'cc-switch is not installed automatically'
        Add-Manual 'Install cc-switch from its official release if needed'
    }
}

function Install-AgentSkills {
    Start-Phase 'Agent skills'
    if ($SkipSkills) {
        Write-Info 'Agent skill installation skipped'
        return
    }

    $sourceRepo = (Resolve-Path (Join-Path $ScriptDir '..\..\..')).Path
    if ((Test-Path (Join-Path $sourceRepo '.git')) -and
        (Test-Path (Join-Path $sourceRepo 'scripts\install-global-skills.sh'))) {
        $repoDir = $sourceRepo
    } else {
        $repoDir = Get-Setting 'PERSONAL_SKILLS_DIR' (Join-Path $HOME 'skills')
        if (-not (Test-Path (Join-Path $repoDir '.git'))) {
            if (Test-Path $repoDir) {
                Write-Warning2 "Cannot clone personal skills over existing path: $repoDir"
                Add-Manual "Move or initialize $repoDir, then install personal/global skills"
                return
            }
            $null = Invoke-Native 'git' @('clone', 'https://github.com/AtticusZeller/skills.git', $repoDir)
        }
    }

    $null = Invoke-Native 'npx' @('skills', 'add', $repoDir, '--skill', '*', '-g', '-y', '--full-depth')
    $installer = Join-Path $repoDir 'scripts\install-global-skills.sh'
    if ($SkipContext7) {
        $null = Invoke-GitBashScript $installer @('--skip-context7-setup')
    } elseif (-not (Invoke-GitBashScript $installer @() -AllowFailure)) {
        Write-Warning2 'External skill or Context7 setup did not complete'
        Add-Manual 'Authenticate Context7 if required, then rerun scripts/install-global-skills.sh in Git Bash'
    }
}

function Install-MachineHandoff {
    Start-Phase 'Machine handoff'
    $arguments = @(
        '--platform', 'windows',
        '--target-home', (ConvertTo-PosixPath $HOME),
        '--proxy-url', $ProxyUrl,
        '--python-version', $PythonVersion,
        '--node-version', $NodeVersion
    )
    if ($DryRun) { $arguments += '--dry-run' }
    $null = Invoke-GitBashScript (Join-Path $ScriptDir 'install-machine-handoff.sh') $arguments -SelfDryRun
}

function Test-ExecutionPolicy {
    foreach ($scope in @('MachinePolicy', 'UserPolicy', 'CurrentUser', 'LocalMachine')) {
        $policy = Get-ExecutionPolicy -Scope $scope
        if ($policy -ne 'Undefined') { break }
    }
    if ($policy -in @('Undefined', 'Restricted', 'AllSigned')) {
        Add-Manual 'Run Set-ExecutionPolicy RemoteSigned -Scope CurrentUser so Scoop and npm PowerShell shims can run'
    }
}

function Invoke-Validation {
    Start-Phase 'Validation'
    if ($DryRun) {
        Write-Info 'Validation skipped during dry-run'
        return
    }
    & $PowerShellExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ScriptDir 'check-dev-machine.ps1') | Out-Host
}

function Write-Summary {
    Write-Host ''
    Write-Host '== Summary =='
    if ($script:Warnings -eq 0) {
        Write-Host 'Bootstrap completed without script warnings.'
    } else {
        Write-Host "Bootstrap completed with $($script:Warnings) warning(s)."
    }
    Add-Manual 'Authenticate gh, hf, wandb, and other account-backed CLIs as needed'
    Write-Host 'Manual follow-up:'
    $index = 1
    foreach ($action in $script:ManualActions) {
        Write-Host "  $index. $action"
        $index++
    }
}

try {
    Initialize-Proxy
    Install-ScoopPackages
    Install-WingetApps
    Install-PythonTools
    Install-Node
    Install-DeveloperClis
    Install-AgentSkills
    Install-MachineHandoff
    Test-ExecutionPolicy
    Invoke-Validation
    Write-Summary
} catch {
    Write-Host "[ERROR] phase failed: $($script:CurrentPhase): $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
