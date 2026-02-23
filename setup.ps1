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

# Peon-ping: install if missing, then link config
$peonPingDir = "$env:USERPROFILE\.claude\hooks\peon-ping"
if (-not (Test-Path $peonPingDir)) {
    Write-Host "Installing peon-ping..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.ps1" -UseBasicParsing | Invoke-Expression
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

# Git defaults
git config --global init.defaultBranch main
Write-Host "✓ git default branch set to main" -ForegroundColor Green

Write-Host "`nDotfiles setup complete!" -ForegroundColor Cyan
