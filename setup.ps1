# Windows Dotfiles Setup Script
# Symlinks configuration files to their proper locations.
# Idempotent: skips items that are already correctly symlinked.
# Each item checks if the target path is already a symlink pointing to the
# correct dotfiles source. If so, it's left alone. Only creates/replaces
# when missing or pointing elsewhere.

# Helper: creates a symlink only if not already correctly linked
function Set-DotfileLink {
    param(
        [string]$Path,
        [string]$Target
    )
    $item = Get-Item $Path -ErrorAction SilentlyContinue
    if ($item -and $item.LinkTarget -eq $Target) {
        Write-Host "· $(Split-Path -Leaf $Path) already linked" -ForegroundColor DarkGray
        return
    }
    if (Test-Path $Path) { Remove-Item $Path -Force }
    New-Item -ItemType SymbolicLink -Path $Path -Target $Target -Force | Out-Null
    Write-Host "✓ $(Split-Path -Leaf $Path) linked" -ForegroundColor Green
}

Write-Host "Setting up dotfiles..." -ForegroundColor Cyan

# PowerShell Profile
$profileDir = Split-Path -Parent $PROFILE
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}
Set-DotfileLink -Path $PROFILE -Target "$PSScriptRoot\PowerShell-Profile.ps1"

# Windows Terminal Settings
$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (Test-Path (Split-Path -Parent $wtSettingsPath)) {
    Set-DotfileLink -Path $wtSettingsPath -Target "$PSScriptRoot\WindowsTerminal-settings.json"
} else {
    Write-Host "⚠ Windows Terminal not found, skipping" -ForegroundColor Yellow
}

# Claude Code global config
$claudeDir = "$env:USERPROFILE\.claude"
if (-not (Test-Path $claudeDir)) {
    New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
}
Set-DotfileLink -Path "$claudeDir\claude.md" -Target "$PSScriptRoot\.claude\claude.md"
Set-DotfileLink -Path "$claudeDir\settings.json" -Target "$PSScriptRoot\.claude\settings.json"

# Peon-ping: install if missing, then link config
$peonPingDir = "$env:USERPROFILE\.claude\hooks\peon-ping"
if (-not (Test-Path $peonPingDir)) {
    Write-Host "Installing peon-ping..." -ForegroundColor Yellow
    & ([scriptblock]::Create((Invoke-WebRequest -Uri "https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.ps1" -UseBasicParsing).Content)) -Packs peasant
}
if (Test-Path $peonPingDir) {
    Set-DotfileLink -Path "$peonPingDir\config.json" -Target "$PSScriptRoot\peon-ping\config.json"
} else {
    Write-Host "⚠ Peon-ping installation failed, skipping config link" -ForegroundColor Yellow
}

# Claude Code scripts
$scriptsDir = "$env:USERPROFILE\.claude\scripts"
if (-not (Test-Path $scriptsDir)) {
    New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
}
Set-DotfileLink -Path "$scriptsDir\screenshot.ps1" -Target "$PSScriptRoot\scripts\screenshot.ps1"
Set-DotfileLink -Path "$scriptsDir\claude-cost.mjs" -Target "$PSScriptRoot\scripts\claude-cost.mjs"

# Claude Code skills
$skillsDir = "$env:USERPROFILE\.claude\skills"
if (-not (Test-Path $skillsDir)) {
    New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null
}
$skillScreenshotDir = "$skillsDir\screenshot"
if (-not (Test-Path $skillScreenshotDir)) {
    New-Item -ItemType Directory -Path $skillScreenshotDir -Force | Out-Null
}
Set-DotfileLink -Path "$skillScreenshotDir\SKILL.md" -Target "$PSScriptRoot\skills\screenshot\SKILL.md"
$skillMakeSkillDir = "$skillsDir\make-skill"
if (-not (Test-Path $skillMakeSkillDir)) {
    New-Item -ItemType Directory -Path $skillMakeSkillDir -Force | Out-Null
}
Set-DotfileLink -Path "$skillMakeSkillDir\SKILL.md" -Target "$PSScriptRoot\skills\make-skill\SKILL.md"

$skillAdoPrDir = "$skillsDir\ado-pr-comments"
if (-not (Test-Path $skillAdoPrDir)) {
    New-Item -ItemType Directory -Path $skillAdoPrDir -Force | Out-Null
}
Set-DotfileLink -Path "$skillAdoPrDir\SKILL.md" -Target "$PSScriptRoot\skills\ado-pr-comments\SKILL.md"

$skillInitRepoDir = "$skillsDir\init-repo"
if (-not (Test-Path $skillInitRepoDir)) {
    New-Item -ItemType Directory -Path $skillInitRepoDir -Force | Out-Null
}
Set-DotfileLink -Path "$skillInitRepoDir\SKILL.md" -Target "$PSScriptRoot\skills\init-repo\SKILL.md"

$skillClaudeCostDir = "$skillsDir\claude-cost"
if (-not (Test-Path $skillClaudeCostDir)) {
    New-Item -ItemType Directory -Path $skillClaudeCostDir -Force | Out-Null
}
Set-DotfileLink -Path "$skillClaudeCostDir\SKILL.md" -Target "$PSScriptRoot\skills\claude-cost\SKILL.md"

$skillDotfilesDir = "$skillsDir\dotfiles"
if (-not (Test-Path $skillDotfilesDir)) {
    New-Item -ItemType Directory -Path $skillDotfilesDir -Force | Out-Null
}
Set-DotfileLink -Path "$skillDotfilesDir\SKILL.md" -Target "$PSScriptRoot\skills\dotfiles\SKILL.md"

# AutoHotkey: install if missing, link script to Startup, and run it
$ahkExe = Get-Command "AutoHotkey64.exe" -ErrorAction SilentlyContinue
if (-not $ahkExe) {
    $ahkExe = Get-Command "AutoHotkey32.exe" -ErrorAction SilentlyContinue
}
if (-not $ahkExe) {
    Write-Host "Installing AutoHotkey..." -ForegroundColor Yellow
    winget install AutoHotkey.AutoHotkey --accept-source-agreements --accept-package-agreements | Out-Null
    Write-Host "✓ AutoHotkey installed" -ForegroundColor Green
} else {
    Write-Host "· AutoHotkey already installed" -ForegroundColor DarkGray
}
$startupDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
Set-DotfileLink -Path "$startupDir\CleanPaste.ahk" -Target "$PSScriptRoot\scripts\CleanPaste.ahk"
# Run it now so the hotkey is active immediately
$ahkPath = (Get-Command "AutoHotkey64.exe" -ErrorAction SilentlyContinue).Source
if (-not $ahkPath) { $ahkPath = (Get-Command "AutoHotkey32.exe" -ErrorAction SilentlyContinue).Source }
if ($ahkPath) {
    $running = Get-Process -Name "AutoHotkey64", "AutoHotkey32" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like "*CleanPaste*" }
    if (-not $running) {
        Start-Process $ahkPath -ArgumentList "$PSScriptRoot\scripts\CleanPaste.ahk"
        Write-Host "✓ CleanPaste.ahk started" -ForegroundColor Green
    } else {
        Write-Host "· CleanPaste.ahk already running" -ForegroundColor DarkGray
    }
}

# Git defaults
git config --global init.defaultBranch main
Write-Host "✓ git default branch set to main" -ForegroundColor Green

Write-Host "`nDotfiles setup complete!" -ForegroundColor Cyan
