---
name: dotfiles
description: Sync the dotfiles repo — pull remote changes and push local changes. Use when user says "sync dotfiles", "/dotfiles", or wants to update their dotfiles.
user-invokable: true
---

# dotfiles

Sync the dotfiles repo (pull then push).

## Steps

1. `cd C:/repos/dotfiles`
2. If there are uncommitted local changes (`git status --porcelain`), stage and commit them: `git add -A && git commit -m "sync: update dotfiles"`
3. `git pull --rebase`
4. `git push` (push local commits, including any just committed)
5. Report what happened (committed N files, pulled N commits, pushed N commits, or already up to date).
