---
name: dotfiles
description: Sync the dotfiles repo — pull remote changes and push local changes. Use when user says "sync dotfiles", "/dotfiles", or wants to update their dotfiles.
user-invokable: true
---

# dotfiles

Sync the dotfiles repo (pull then push).

## Steps

1. `cd C:/repos/dotfiles`
2. Switch GitHub authentication to the repository owner: `gh auth switch --hostname github.com --user kredenac`
3. If there are uncommitted local changes (`git status --porcelain`), stage and commit them: `git add -A && git commit -m "sync: update dotfiles"`
4. `git pull --rebase`
5. `git push` (push local commits, including any just committed)
6. Report what happened (committed N files, pulled N commits, pushed N commits, or already up to date).
