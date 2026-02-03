# Windows Dotfiles Setup Script
# Copies configuration files to their proper locations

Write-Host "Setting up dotfiles..." -ForegroundColor Cyan

# PowerShell Profile
$profilePath = $PROFILE
$profileDir = Split-Path -Parent $profilePath
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}
Copy-Item -Path ".\PowerShell-Profile.ps1" -Destination $profilePath -Force
Write-Host "✓ PowerShell profile installed" -ForegroundColor Green

# Windows Terminal Settings
$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (Test-Path (Split-Path -Parent $wtSettingsPath)) {
    Copy-Item -Path ".\WindowsTerminal-settings.json" -Destination $wtSettingsPath -Force
    Write-Host "✓ Windows Terminal settings installed" -ForegroundColor Green
} else {
    Write-Host "⚠ Windows Terminal not found, skipping" -ForegroundColor Yellow
}

# Claude Code global config
$claudeDir = "$env:USERPROFILE\.claude"
if (-not (Test-Path $claudeDir)) {
    New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
}
$claudeConfigPath = "$claudeDir\claude.md"
if (Test-Path $claudeConfigPath) {
    Remove-Item $claudeConfigPath -Force
}
New-Item -ItemType SymbolicLink -Path $claudeConfigPath -Target "$PSScriptRoot\.claude\claude.md" -Force | Out-Null
Write-Host "✓ Claude Code config linked" -ForegroundColor Green

Write-Host "`nDotfiles setup complete!" -ForegroundColor Cyan
