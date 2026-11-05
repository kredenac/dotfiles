---
name: dotfiles
description: Sync the dotfiles repo — pull remote changes and push local changes. Use when user says "sync dotfiles", "/dotfiles", or wants to update their dotfiles.
---

# dotfiles

Sync the dotfiles repo (pull then push).

## Steps

1. `cd C:/repos/dotfiles`
2. On machines where the company account `nidimitr_microsoft` is signed in to `gh` (check `gh auth status --hostname github.com`), it is the default active account and `kredenac` is used only for this sync. Personal machines may not have it; there, leave `kredenac` active.
3. Read the signed-in Windows user's UPN with `whoami /upn`. Only when it is exactly `nidimitr@microsoft.com`, `%LOCALAPPDATA%\agency\agency.toml` exists, and `agency` is already installed:
   - Preserve the tracked `remote_config` entries when merging live Agency changes into `C:/repos/dotfiles/agency.toml`; never replace the tracked file with the live file wholesale.
   - Preserve the tracked `market:apiary@opg-microsoft/wordengai-agents` entry in `plugins.default`; do not add an empty `profiles.word-copilot.plugins.default` override.
   - Validate the merged config with `agency config check` and confirm `agency config profiles --json` contains `word-copilot` with the `word-knowledgebase` plugin before committing it.
   - After validation, copy the merged tracked config back to `%LOCALAPPDATA%\agency\agency.toml` so new sessions use the same `remote_config` and plugin configuration.
   - Never install Agency as part of this skill. If the UPN cannot be determined, differs, or Agency is unavailable, skip Agency config syncing and report that it was skipped.
4. Switch GitHub authentication to the repository owner: `gh auth switch --hostname github.com --user kredenac`
5. If there are uncommitted local changes (`git status --porcelain`), stage and commit them: `git add -A && git commit -m "sync: update dotfiles"`
6. `git pull --rebase`
7. `git push` (push local commits, including any just committed)
8. In a `finally`/cleanup step that also runs after failures, switch back to the company account only if `nidimitr_microsoft` is signed in to `gh`, even if `kredenac` was active before the sync:
   `gh auth switch --hostname github.com --user nidimitr_microsoft`
   If it is not signed in, skip this step and stay on `kredenac`.
9. Report what happened (committed N files, pulled N commits, pushed N commits, restored account, or already up to date).
