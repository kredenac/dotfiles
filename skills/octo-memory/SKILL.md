---
name: octo-memory
description: Sync and load Dimi's personal "Octo" memory from the nidimitr_microsoft/octo-memory repo, then use MEMORY.md as an index to navigate to the right context. Use when the user says "/octo-memory", "octo memory", "load my memory", "check octo memory", or asks a question that likely needs their persisted personal/work context (team, ADO area owners, azure admin recipes, daily logs, preferences, hard rules).
user-invokable: true
---

# octo-memory

Reuse the personal memory files Dimi keeps in the private GitHub repo
`nidimitr_microsoft/octo-memory`. On invocation, sync the repo to get the latest, then read
`MEMORY.md` (the index) and navigate into whatever topic files are relevant to the current task.

Local clone path: `C:\repos\octo-memory`
Remote: `https://github.com/nidimitr_microsoft/octo-memory` (private, default branch `main`)

## Steps

### 1. Sync the repo

The repo is private and readable by the `nidimitr_microsoft` GitHub account. If a git/gh
operation fails due to permissions, switch accounts with `gh auth switch --user nidimitr_microsoft`
and retry.

- **If `C:\repos\octo-memory` already exists:** commit any local changes, rebase onto the latest
  remote changes, then push.
  ```powershell
  if (git -C "C:\repos\octo-memory" status --porcelain) {
      git -C "C:\repos\octo-memory" add -A
      git -C "C:\repos\octo-memory" commit -m "sync: update memory"
  }
  git -C "C:\repos\octo-memory" pull --rebase
  git -C "C:\repos\octo-memory" push
  ```
- **If it does not exist:** clone it.
  ```powershell
  git clone https://github.com/nidimitr_microsoft/octo-memory.git "C:\repos\octo-memory"
  ```

If the rebase has conflicts, resolve them autonomously rather than leaving the repository paused:

1. Inspect the local commit and upstream changes for every conflicted file.
2. Preserve both sides when changes are independent. For content conflicts, keep the latest
   upstream structure and reapply the local intent.
3. Treat a locally deleted file as an intentional deletion even when upstream modified it. Remove
   the file, remove any newly introduced references to it, and record a concise summary of the
   deleted content for the user.
4. Continue the rebase non-interactively, verify the index has no stale links to deleted files,
   and push.

Use `git rebase --abort` only when the local intent cannot be determined safely. Never discard
local or upstream changes merely to make the rebase succeed. If commit, rebase, or push still fails
after resolving inferable conflicts, report the exact blocker to the user.

### 2. Read the index

Read `C:\repos\octo-memory\MEMORY.md`. It is the master index and contains:
- **About / User** — who Dimi is (role, location, timezone, email).
- **Topic Files** — links to focused files (relative paths in the repo), each with a one-line
  description of what it holds and when to read it.
- **Communication Style, Key Facts, Hard Rules** — durable preferences and non-negotiable rules.
- **Agent Skills** — Octo's own skill catalog (informational).

Treat `MEMORY.md` as a routing table, not the whole answer. Skim the Topic Files list and note
which files map to the user's current need.

### 3. Navigate to the relevant context

Based on the user's question / current task, open the specific topic file(s) referenced in
`MEMORY.md` rather than reading everything. Examples of the mapping:
- Team / direct reports / stakeholders -> `team.md`
- ADO area/domain ownership & routing -> `area-owners.md`
- Azure subscription / role-assignment recipes -> `azure-admin.md`
- Kusto clusters & MCP setup -> `kusto.md`

If the user's request is open-ended ("load my memory", "what do you know about me"), summarize the
User + Key Facts + Hard Rules sections from `MEMORY.md` and list the available topic files so they
can point you at one.

### 4. Apply the context

Use the loaded facts, preferences, and hard rules to inform your response and any subsequent work
in this session. Honor the Hard Rules from `MEMORY.md` (they are explicit user preferences).

## Notes

- **Content is read-only by default.** This skill does not create or edit memory content unless the
  user explicitly asks, but it commits and pushes pre-existing local changes during synchronization.
- **Don't over-read.** `MEMORY.md` links many topic files — only open the ones relevant to the task.
- **Path is Windows-style** (`C:\repos\octo-memory`). Topic file links inside `MEMORY.md` are
  repo-relative POSIX paths; resolve them against `C:\repos\octo-memory\`.
- Some links in `MEMORY.md` point at paths that live in Octo's runtime (e.g. `system/…`,
  `user-data/…`) and may not exist in this repo clone — skip any that aren't present.
- Auth: the active `gh`/git account must be `nidimitr_microsoft`. Use `gh auth switch` if a
  pull/clone is denied.
