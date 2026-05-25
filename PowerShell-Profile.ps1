# GitHub Copilot CLI: yolo mode (allow all permissions without prompts)
$env:COPILOT_ALLOW_ALL = "true"

# Import posh-git for Git prompt integration
Import-Module posh-git

# Git shortcuts
function Get-GitCommit { & git add -A; git commit -m $args }
New-Alias -Name gac -Value Get-GitCommit

function Get-GitStatus { & git status }
New-Alias -Name gs -Value Get-GitStatus

function Get-GitMerge { & git fetch; git merge origin/main }
New-Alias -Name gfm -Value Get-GitMerge

function GitSquashUnpushed {
    param([string]$Message)

    $upstream = git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>$null
    if (-not $upstream) {
        Write-Error "No upstream branch set. Push first or set upstream with 'git push --set-upstream origin <branch>'"
        return
    }

    $unpulled = [int](git rev-list --count "$upstream..HEAD")
    if ($unpulled -lt 2) {
        Write-Host "Nothing to squash ($unpulled unpushed commit)."
        return
    }

    git reset --soft "HEAD~$unpulled"
    git commit -m "$Message"
    Write-Host "Squashed $unpulled commits into one."
}

New-Alias -Name gsq -Value GitSquashUnpushed

# Agency Copilot in yolo mode
function Invoke-Copilot { agency copilot --yolo @args }
Set-Alias -Name c -Value Invoke-Copilot

# Custom prompt with posh-git integration and Windows Terminal support
function prompt
{
    $loc = Get-Location

    $prompt = & $GitPromptScriptBlock

    $prompt += "$([char]27)]9;12$([char]7)"
    if ($loc.Provider.Name -eq "FileSystem")
    {
        $prompt += "$([char]27)]9;9;`"$($loc.ProviderPath)`"$([char]27)\"
    }

    $prompt
}
