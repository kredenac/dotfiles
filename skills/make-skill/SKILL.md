---
name: make-skill
description: Scaffold a new Claude Code skill. Creates the SKILL.md in the dotfiles repo, adds it to setup.ps1, and symlinks it immediately. Use when the user says "make a skill", "create a skill", "new skill", or "/make-skill".
user-invokable: true
---

# make-skill

Create a new Claude Code skill, fully wired up and immediately active.

## Steps

### 1. Gather details

Ask the user (using AskUserQuestion) for:

- **Skill name** — lowercase, kebab-case (e.g. `review-pr`, `deploy`)
- **Description** — one-liner for the frontmatter `description` field (explains when Claude should invoke it)
- **User-invokable** — should it be callable via `/skill-name`? (almost always yes)
- **What it does** — brief explanation of the skill's purpose and steps

### 2. Create the SKILL.md

Create `C:\repos\dotfiles\skills\<name>\SKILL.md` with this structure:

```markdown
---
name: <name>
description: <description>
user-invokable: <true|false>
---

# <name>

<What the skill does — one sentence summary.>

## Steps

<Numbered steps Claude should follow when this skill is invoked.>

## Notes

<Any caveats, prerequisites, or tips.>
```

Fill in the Steps and Notes sections based on what the user described. Write clear, actionable instructions that Claude can follow.

### 3. (Optional) Create a companion script

If the skill needs to run a script (PowerShell, bash, etc.), create it at `C:\repos\dotfiles\scripts\<name>.ps1` (or appropriate extension).

Then add a symlink line for the script in `setup.ps1` under the "Claude Code scripts" section:

```powershell
Set-DotfileLink -Path "$scriptsDir\<name>.ps1" -Target "$PSScriptRoot\scripts\<name>.ps1"
```

### 4. Add symlink block to setup.ps1

Open `C:\repos\dotfiles\setup.ps1` and insert a new block under the "Claude Code skills" section, right after the last skill block (before the `# Git defaults` comment). Follow the exact existing pattern:

```powershell
$skill<PascalName>Dir = "$skillsDir\<name>"
if (-not (Test-Path $skill<PascalName>Dir)) {
    New-Item -ItemType Directory -Path $skill<PascalName>Dir -Force | Out-Null
}
Set-DotfileLink -Path "$skill<PascalName>Dir\SKILL.md" -Target "$PSScriptRoot\skills\<name>\SKILL.md"
```

Where `<PascalName>` is the skill name in PascalCase (e.g. `review-pr` → `ReviewPr`).

### 5. Activate immediately

Run these commands via Bash to create the symlink right now without re-running full setup:

```bash
powershell -ExecutionPolicy Bypass -Command "
    \$dir = \"$env:USERPROFILE\.claude\skills\<name>\";
    if (-not (Test-Path \$dir)) { New-Item -ItemType Directory -Path \$dir -Force | Out-Null };
    New-Item -ItemType SymbolicLink -Path \"\$dir\SKILL.md\" -Target \"C:\repos\dotfiles\skills\<name>\SKILL.md\" -Force | Out-Null
"
```

### 6. Verify

Confirm the symlink exists and points to the right target:

```bash
powershell -Command "Get-Item \"$env:USERPROFILE\.claude\skills\<name>\SKILL.md\" | Select-Object FullName, LinkTarget"
```

Tell the user the skill is ready. They can use `/<name>` in their next Claude Code session (or current session if they reload).

## Notes

- All skills live in `C:\repos\dotfiles\skills\<name>\SKILL.md` and are symlinked to `~/.claude/skills/<name>/SKILL.md`.
- The `setup.ps1` script is idempotent — running it again will report "already linked" for existing skills.
- If the skill needs a companion script, it goes in `C:\repos\dotfiles\scripts\` and is symlinked to `~/.claude/scripts/`.
