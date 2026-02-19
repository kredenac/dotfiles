# Global Claude Code Instructions

## Coding Style
- Write clean, readable code with meaningful variable names
- Add comments only when logic isn't self-evident

## Communication Preferences
- Be concise—skip fluff and get to the point
- Ask clarifying questions when requirements are ambiguous
- Question me if you think I'm wrong

## Technology Preferences
- TS, JS, Python, Pwsh

## Commands
- When I say "gac" - you add and commit everything in this git dir
- When I say "push" - you do gac and then push
- When I say "open your config" - open the dir "%USERPROFILE%\.claude" in vscode
- use "gh" (github) commands to create/update repositories on my github as needed

## Windows Bash Paths
- The Bash tool runs Git Bash. Windows paths like `C:\foo\bar` get mangled (backslashes treated as escapes).
- In Bash, always use Unix-style paths: `/c/repos/...` instead of `C:\repos\...`
- Use Unix commands (`mv`, `cp`, `mkdir -p`) not Windows ones (`move`, `copy`, `md`)
- Other tools (Read, Write, Edit, Glob) handle Windows paths fine — this only applies to Bash.

## Azure DevOps (ADO)
- Org: `office` (`https://office.visualstudio.com`), Project: `OC`
- Use `[Microsoft.VSTS.Common.ClosedBy]` for closed/resolved items, not `[System.AssignedTo]`
- Example: `az boards query --wiql "SELECT [System.Id], [System.Title], [System.State], [System.WorkItemType], [Microsoft.VSTS.Common.ClosedDate] FROM WorkItems WHERE [Microsoft.VSTS.Common.ClosedBy] = '<Name>' AND ([System.State] = 'Closed' OR [System.State] = 'Resolved') ORDER BY [Microsoft.VSTS.Common.ClosedDate] DESC" --output table`
