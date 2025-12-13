# Run  $Profile to find out where the file is
function Get-GitCommit { & git add -A; git commit -m $args }
New-Alias -Name gac -Value Get-GitCommit
 
function Get-GitStatus { & git status }
New-Alias -Name gs -Value Get-GitStatus
 
function Get-GitMerge { & git fetch; git merge origin/main  }
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
 
# add stuff below if you want to use push git
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
 
Import-Module posh-git
 
# Set-Location 'C:\Users\Nikola\'