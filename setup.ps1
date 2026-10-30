# Windows Dotfiles Setup Script
# Symlinks configuration files to their proper locations.
# Idempotent: skips items that are already correctly symlinked.
# Each item checks if the target path is already a symlink pointing to the
# correct dotfiles source. If so, it's left alone. Only creates/replaces
# when missing or pointing elsewhere.

param(
    [switch]$SkipAutoHotkey
)

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

# GitHub Copilot CLI global config
$copilotDir = "$env:USERPROFILE\.copilot"
if (-not (Test-Path $copilotDir)) {
    New-Item -ItemType Directory -Path $copilotDir -Force | Out-Null
}
Set-DotfileLink -Path "$copilotDir\settings.json" -Target "$PSScriptRoot\.copilot\settings.json"
Set-DotfileLink -Path "$copilotDir\copilot-instructions.md" -Target "$PSScriptRoot\.copilot\copilot-instructions.md"
if ($env:COMPUTERNAME -eq "DIMI-PC") {
    Write-Host "· mcp-config.json kept machine-local on DIMI-PC" -ForegroundColor DarkGray
} else {
    Set-DotfileLink -Path "$copilotDir\mcp-config.json" -Target "$PSScriptRoot\.copilot\mcp-config.json"
}
Set-DotfileLink -Path "$copilotDir\permissions-config.json" -Target "$PSScriptRoot\.copilot\permissions-config.json"

if (-not $SkipAutoHotkey) {
    # AutoHotkey: install if missing, link script to Startup, and run it
    $ahkPath = (Get-Command "AutoHotkey64.exe" -ErrorAction SilentlyContinue).Source
    if (-not $ahkPath) {
        $ahkPath = (Get-Command "AutoHotkey32.exe" -ErrorAction SilentlyContinue).Source
    }
    if (-not $ahkPath) {
        $ahkPath = @(
            "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe"
            "${env:ProgramFiles(x86)}\AutoHotkey\v2\AutoHotkey32.exe"
        ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    }
    if (-not $ahkPath) {
        Write-Host "Installing AutoHotkey..." -ForegroundColor Yellow
        winget install AutoHotkey.AutoHotkey --accept-source-agreements --accept-package-agreements | Out-Null
        Write-Host "✓ AutoHotkey installed" -ForegroundColor Green
        $ahkPath = @(
            "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe"
            "${env:ProgramFiles(x86)}\AutoHotkey\v2\AutoHotkey32.exe"
        ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    } else {
        Write-Host "· AutoHotkey already installed" -ForegroundColor DarkGray
    }
    $startupDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    Set-DotfileLink -Path "$startupDir\CleanPaste.ahk" -Target "$PSScriptRoot\scripts\CleanPaste.ahk"
    # Run it now so the hotkey is active immediately
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
}

# Agency
if (-not (Get-Command "agency" -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Agency..." -ForegroundColor Yellow
    Invoke-Expression "& { $(Invoke-RestMethod https://aka.ms/InstallTool.ps1) } agency"
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
        [System.Environment]::GetEnvironmentVariable("Path", "User")
    Write-Host "✓ Agency installed" -ForegroundColor Green
} else {
    Write-Host "· Agency already installed" -ForegroundColor DarkGray
}

# Agency global config
$agencyDir = "$env:LOCALAPPDATA\agency"
if (-not (Test-Path $agencyDir)) {
    New-Item -ItemType Directory -Path $agencyDir -Force | Out-Null
}
$agencyConfigPath = "$agencyDir\agency.toml"
if ((Test-Path $agencyConfigPath) -and (Get-Item $agencyConfigPath).LinkType -eq 'SymbolicLink') {
    Remove-Item $agencyConfigPath -Force
}
Copy-Item -Path "$PSScriptRoot\agency.toml" -Destination $agencyConfigPath -Force
Write-Host "✓ Agency config copied" -ForegroundColor Green
agency config check | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Agency config validation failed"
}
Write-Host "✓ Agency config validated" -ForegroundColor Green
$agencyProfiles = agency config profiles --json | ConvertFrom-Json
$wordCopilotProfile = $agencyProfiles | Where-Object name -eq "word-copilot"
if (-not $wordCopilotProfile) {
    throw "Agency profile 'word-copilot' was not resolved"
}
if (-not ($wordCopilotProfile.plugins -contains "word-knowledgebase")) {
    throw "Agency profile 'word-copilot' did not resolve the word-knowledgebase plugin"
}
Write-Host "✓ Word Copilot profile available" -ForegroundColor Green

# Clean up legacy location if it's a symlink we previously created
$legacyLink = "$env:USERPROFILE\.agency\agency.toml"
if ((Test-Path $legacyLink) -and (Get-Item $legacyLink).LinkType -eq 'SymbolicLink') {
    Remove-Item $legacyLink -Force
    Write-Host "✓ Removed legacy symlink at $legacyLink" -ForegroundColor Yellow
}

# Git defaults
git config --global init.defaultBranch main
Write-Host "✓ git default branch set to main" -ForegroundColor Green

Write-Host "`nDotfiles setup complete!" -ForegroundColor Cyan
