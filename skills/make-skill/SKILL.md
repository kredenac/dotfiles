---
name: make-skill
description: Scaffold a new skill for GitHub Copilot CLI. Creates the SKILL.md in the dotfiles skills directory so Copilot CLI auto-discovers it. Use when the user says "make a skill", "create a skill", "new skill", or "/make-skill".
---

# make-skill

Create a new skill for GitHub Copilot CLI (GHCP), fully wired up and immediately usable.

GHCP CLI discovers skills directly from the directories listed under `skillDirectories` in
`~/.copilot/settings.json` — currently `C:\repos\dotfiles\skills`. That means a skill becomes
available simply by creating `C:\repos\dotfiles\skills\<name>\SKILL.md`. No symlink is required
for GHCP.

## Steps

### 1. Gather details

Ask the user for:

- **Skill name** — lowercase, kebab-case (e.g. `review-pr`, `deploy`)
- **Description** — one-liner for the frontmatter `description` field. Make it trigger-rich:
  describe *when* the assistant should invoke it and include the literal `/skill-name` invocation
  and any natural-language phrases the user is likely to say.
- **What it does** — brief explanation of the skill's purpose and the steps it should follow

Use the AskUserQuestion tool if available; otherwise just ask in chat.

### 2. Create the SKILL.md

Create `C:\repos\dotfiles\skills\<name>\SKILL.md` with this structure:

```markdown
---
name: <name>
description: <description>
---

# <name>

<What the skill does — one sentence summary.>

## Steps

<Numbered, actionable steps the assistant should follow when this skill is invoked.>

## Notes

<Any caveats, prerequisites, or tips.>
```

Fill in Steps and Notes based on what the user described. Write clear, concrete instructions the
assistant can follow without further clarification. Since this directory is already a GHCP
`skillDirectory`, the file is the only thing GHCP needs.

### 3. (Optional) Create a companion script

If the skill needs to run a script (PowerShell preferred on Windows), create it at
`C:\repos\dotfiles\scripts\<name>.ps1` and have the SKILL.md invoke it. Keep simple logic
(a couple of git or shell commands) inline in the SKILL.md instead.

### 4. Activate in GHCP CLI

The skill is auto-discovered from `skillDirectories`. To make it available in the **current**
session, run `/skills reload` or restart the CLI. New sessions pick it up automatically. Verify it
loaded:

- Run `/env` (or check the skills list) and confirm `<name>` appears, or
- Confirm the file exists: `Test-Path "C:\repos\dotfiles\skills\<name>\SKILL.md"`

### 5. Tell the user it's ready

Confirm the skill file exists and (if reloaded) that GHCP lists it. Let them know they can invoke
it by mentioning `/<name>` in a prompt, such as `Use the /<name> skill`, or by using the trigger
phrases in its description.

## Notes

- **GHCP primary:** skills live in `C:\repos\dotfiles\skills\<name>\SKILL.md` and are discovered
  via `skillDirectories` in `~/.copilot/settings.json`. No symlink needed for GHCP.
- Keep frontmatter to the documented Agent Skills fields. `name` and `description` are required;
  add `license` or `allowed-tools` only when the skill needs them.
- Companion scripts go in `C:\repos\dotfiles\scripts\`.
