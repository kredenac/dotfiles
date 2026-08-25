---
name: dotfiles
description: Sync the dotfiles repo — pull remote changes and push local changes. Use when user says "sync dotfiles", "/dotfiles", or wants to update their dotfiles.
user-invokable: true
---

# dotfiles

Sync the dotfiles repo (pull then push).

## Steps

1. `cd C:/repos/dotfiles`
2. If `%LOCALAPPDATA%\agency\agency.toml` exists, validate it with `agency config check`, then copy it to `C:/repos/dotfiles/agency.toml` so plugin installs and other global Agency changes are included in the sync.
3. Record the initially active GitHub account:
   `gh auth status --active --hostname github.com --json hosts --jq '.hosts["github.com"][0].login'`
4. Switch GitHub authentication to the repository owner: `gh auth switch --hostname github.com --user kredenac`
5. If there are uncommitted local changes (`git status --porcelain`), stage and commit them: `git add -A && git commit -m "sync: update dotfiles"`
6. `git pull --rebase`
7. `git push` (push local commits, including any just committed)
8. In a `finally`/cleanup step that also runs after failures, switch back to the initially active GitHub account when it was not `kredenac` (for example, `nidimitr_microsoft`):
   `gh auth switch --hostname github.com --user <initial-account>`
9. Report what happened (committed N files, pulled N commits, pushed N commits, restored account, or already up to date).
