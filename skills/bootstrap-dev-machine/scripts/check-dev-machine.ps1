#Requires -Version 5.1
# Read-only validation for the Windows development-machine baseline.
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Continue'

$script:WarnCount = 0
# Python CLIs such as sbc print emoji; keep them from crashing in cp1252 consoles.
$env:PYTHONUTF8 = '1'
$RunnableExtensions = @('.exe', '.com', '.cmd', '.bat', '.ps1')

function Write-Check([string]$Status, [string]$Kind, [string]$Name, [string]$Detail) {
    Write-Host ('{0,-4} {1,-7} {2,-12} {3}' -f $Status, $Kind, $Name, $Detail)
    if ($Status -eq 'WARN') { $script:WarnCount++ }
}

# Ignores extensionless files on PATH, which Windows cannot execute.
function Find-Cmd([string]$Name) {
    return Get-Command $Name -CommandType Application, ExternalScript -All -ErrorAction SilentlyContinue |
        Where-Object { $RunnableExtensions -contains [IO.Path]::GetExtension($_.Source).ToLowerInvariant() } |
        Select-Object -First 1
}

function Test-Cmd([string]$Name) {
    $command = Find-Cmd $Name
    if ($command) {
        Write-Check 'OK' 'command' $Name $command.Source
    } else {
        Write-Check 'WARN' 'command' $Name 'missing'
    }
}

function Test-PathEntry([string]$Path) {
    if (Test-Path $Path) {
        Write-Check 'OK' 'path' '' $Path
    } else {
        Write-Check 'WARN' 'path' '' "$Path missing"
    }
}

function Show-Version([string]$Label, [string]$File, [string[]]$Arguments) {
    $output = ''
    $command = Find-Cmd $File
    if ($command) {
        try {
            $output = (& $command.Source @Arguments 2>$null | Where-Object { "$_".Trim() } | Select-Object -First 1)
        } catch {
            $output = "<failed: $($_.Exception.Message)>"
        }
    }
    Write-Host ('INFO {0,-14} {1}' -f $Label, $output)
}

Write-Host '== Commands =='
foreach ($name in @('scoop', 'winget', 'git', 'rg', 'uv', 'sbc', 'node', 'npm', 'npx',
        'codex', 'claude', 'gh', 'hf', 'cc-switch', 'nvitop', 'wandb')) {
    Test-Cmd $name
}

Write-Host ''
Write-Host '== Versions =='
Show-Version 'git' 'git' @('--version')
Show-Version 'uv' 'uv' @('--version')
Show-Version 'rg' 'rg' @('--version')
Show-Version 'sbc' 'sbc' @('version')
Show-Version 'node' 'node' @('-v')
Show-Version 'npm' 'npm' @('-v')
Show-Version 'codex' 'codex' @('--version')
Show-Version 'claude' 'claude' @('--version')
Show-Version 'gh' 'gh' @('--version')
Show-Version 'hf' 'hf' @('--version')
Show-Version 'uv python' 'uv' @('python', 'find')

Write-Host ''
Write-Host '== Paths =='
Test-PathEntry (Join-Path $HOME '.local\bin')
Test-PathEntry (Join-Path $HOME 'README.md')
Test-PathEntry (Join-Path $HOME '.codex\AGENTS.md')
Test-PathEntry (Join-Path $HOME '.claude\CLAUDE.md')
Test-PathEntry (Join-Path $HOME '.agents\skills')
Test-PathEntry (Join-Path $HOME '.claude\rules\context7.md')

$claudeRules = Join-Path $HOME '.claude\CLAUDE.md'
if (Test-Path $claudeRules) {
    $imports = @('@../.codex/AGENTS.md', '@~/.codex/AGENTS.md')
    if (Get-Content $claudeRules | Where-Object { $imports -contains $_.Trim() }) {
        Write-Check 'OK' 'import' 'claude' 'shared Codex instructions'
    } else {
        Write-Check 'WARN' 'import' 'claude' "$claudeRules does not import ~/.codex/AGENTS.md"
    }
}

Write-Host ''
Write-Host '== Proxy =='
$gitHttp = ''
$gitHttps = ''
if (Find-Cmd 'git') {
    $gitHttp = (& git config --global --get http.proxy 2>$null)
    $gitHttps = (& git config --global --get https.proxy 2>$null)
}
$scoopProxy = ''
$scoopConfig = Join-Path $HOME '.config\scoop\config.json'
if (Test-Path $scoopConfig) {
    $config = Get-Content $scoopConfig -Raw | ConvertFrom-Json
    if ($config.PSObject.Properties['proxy']) { $scoopProxy = $config.proxy }
}
foreach ($item in @(
        @('git http.proxy', $gitHttp), @('git https.proxy', $gitHttps),
        @('scoop proxy', $scoopProxy), @('HTTPS_PROXY', $env:HTTPS_PROXY))) {
    $value = if ($item[1]) { $item[1] } else { '<unset>' }
    Write-Host ('INFO {0,-16} {1}' -f $item[0], $value)
}

Write-Host ''
if ($script:WarnCount -eq 0) {
    Write-Host 'OK bootstrap checks passed'
} else {
    Write-Host "WARN bootstrap checks completed with $($script:WarnCount) warning(s)"
}
exit 0
