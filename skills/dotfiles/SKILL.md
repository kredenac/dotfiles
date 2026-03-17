---
name: dotfiles
description: Sync the dotfiles repo — pull remote changes and push local changes. Use when user says "sync dotfiles", "/dotfiles", or wants to update their dotfiles.
user-invokable: true
---

# dotfiles

Sync the dotfiles repo (pull then push).

## Steps

1. `cd C:/repos/dotfiles`
2. `git pull --rebase`
3. Check if there are any local commits to push: `git status`
4. If ahead of remote, `git push`
5. Report what happened (pulled N commits, pushed N commits, or already up to date).
