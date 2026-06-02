---
name: word-copilot-oncall
description: Helper for Word Copilot on-call (OCE) duty — triage the queue, investigate incidents, and follow team TSGs. Use when user says "oncall", "OCE", "triage queue", "/word-copilot-oncall", or asks about Word Copilot incidents/ICM/queue items.
user-invokable: true
---

# word-copilot-oncall

On-call (OCE) helper for the **Word Copilot** team. Covers ICM queue triage, ADO work-item lookup, telemetry queries, and pointers to the official TSGs.

## Key facts

- **ICM queue name:** `Word Copilot`
- **ADO org / project:** `office` / `OC`
- **Primary area path:** `OC\Word\Copilot` (and sub-areas — see `C:\repos\area-path-owners.md` for owners by sub-area)
- **Onboarding & TSGs (read this first):** https://office.visualstudio.com/OC/_wiki/wikis/OC.wiki/99261/Word-Copilot-OCE

## Steps

When invoked, do whatever the user asks. If they're starting a shift or want a triage pass, default to:

1. **Pull active incidents** from the `Word Copilot` ICM queue using the `icm` MCP. Sort by severity, then age.
2. For each incident, fetch:
   - Title, severity, status, owning team, current assignee.
   - Linked ADO work items (via the `ado` MCP, project `OC`).
   - Recent correlated telemetry from Kusto (via the `kusto` MCP) — typical clusters: AugLoop (`odxaugloop.eastus.kusto.windows.net`), Aria (`kusto.aria.microsoft.com`), 1ES (`1es.kusto.windows.net`).
3. **Cross-reference the TSG wiki** (link above) — most recurring incidents have a documented mitigation. Quote the TSG section that applies.
4. **Summarise**: severity-sorted table of incidents with: ID, title, age, suspected area, suggested next action / TSG link.
5. If asked to **handoff** or **start/end shift**, draft a Teams message (via the `teams` MCP) or email (via the `outlook` MCP) with the open-incident summary.

## Required MCPs

This skill assumes the following MCP servers are enabled in `C:\repos\dotfiles\.copilot\mcp-config.json` (already configured for this machine — re-run `C:\repos\dotfiles\setup.ps1` if missing):

| MCP       | Purpose                                                        |
|-----------|----------------------------------------------------------------|
| `icm`     | Read/update ICM incidents in the `Word Copilot` queue          |
| `ado`     | Query/update ADO work items in org `office`, project `OC`      |
| `kusto`   | Telemetry queries against AugLoop / Aria / 1ES clusters        |
| `teams`   | Post status updates and handoff messages to team channels      |
| `outlook` | Send incident summaries and handoff emails                     |

All five are provided by the local `agency.exe` binary (see `mcp-config.json` for exact args). If a server is missing, add a block following the existing pattern in that file and restart the CLI.

## Useful ADO queries

- **My on-call items** (replace `<Name>`):
  ```
  az boards query --wiql "SELECT [System.Id], [System.Title], [System.State] FROM WorkItems WHERE [System.AreaPath] UNDER 'OC\Word\Copilot' AND [System.AssignedTo] = '<Name>' AND [System.State] <> 'Closed' ORDER BY [System.ChangedDate] DESC" --output table
  ```
- **Recently closed by a team-mate** — use `[Microsoft.VSTS.Common.ClosedBy]` (not `[System.AssignedTo]`):
  ```
  az boards query --wiql "SELECT [System.Id], [System.Title], [Microsoft.VSTS.Common.ClosedDate] FROM WorkItems WHERE [System.AreaPath] UNDER 'OC\Word\Copilot' AND [Microsoft.VSTS.Common.ClosedBy] = '<Name>' AND [System.State] IN ('Closed','Resolved') ORDER BY [Microsoft.VSTS.Common.ClosedDate] DESC" --output table
  ```

## Notes

- **Always read the TSG wiki** before doing anything destructive — most issues have a known mitigation there.
- For area-path → owner lookups, see the generated report at `C:\repos\area-path-owners.md`.
- ICM acks/mitigation comments must follow the team's response-time SLA documented in the OCE wiki.
- Don't auto-close incidents without confirming with the assigned engineer.
