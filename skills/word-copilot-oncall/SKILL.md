---
name: word-copilot-oncall
description: Helper for Word Copilot on-call (OCE) duty — triage the queue, investigate incidents, and follow team TSGs. Use when user says "oncall", "OCE", "triage queue", "/word-copilot-oncall", or asks about Word Copilot incidents/ICM/queue items.
user-invokable: true
---

# word-copilot-oncall

On-call (OCE) helper for the **Word Copilot** team. Covers ICM queue triage, ADO work-item lookup, telemetry queries, and pointers to the official TSGs.

## Setup (works on a fresh machine — no repo or config file needed)

The MCP servers used here ship inside the `agency` binary (https://aka.ms/agency). You can launch in **YOLO mode** so the many read-only investigation calls don't prompt for approval on every step:

- **Copilot CLI:** `agency copilot --yolo`

Run `agency mcp <name> --help` to see a server's options. If you keep a persisted MCP config instead, mirror these same `agency mcp <name>` invocations.

## Stable anchors (everything else is resolved live, never hardcoded)

- **ICM queue / owning service:** `Word Copilot`
- **ADO org / project:** `office` / `OC`, primary area path `OC\Word\Copilot`
- **Onboarding & TSGs (read first):** https://office.visualstudio.com/OC/_wiki/wikis/OC.wiki/99261/Word-Copilot-OCE

## Steps

When invoked, do whatever the user asks. If they're starting a shift or want a triage pass, default to:

1. **Pull active incidents** from the `Word Copilot` ICM queue using the `icm` MCP. Sort by severity, then age.
2. For each incident, fetch:
   - Title, severity, status, owning team, current assignee.
   - Linked ADO work items (via the `ado` MCP, project `OC`).
   - Recent correlated telemetry from Kusto (via the `kusto` MCP) — typical clusters: AugLoop (`odxaugloop.eastus.kusto.windows.net`), Aria (`kusto.aria.microsoft.com`), 1ES (`1es.kusto.windows.net`).
3. **Cross-reference the TSG wiki** (link above) — most recurring incidents have a documented mitigation. Quote the TSG section that applies.
4. **Summarise**: severity-sorted table of incidents with: ID, title, age, suspected area, suggested next action / TSG link.
5. If asked to **handoff** or **start/end shift**, draft a Teams message (via the `teams` MCP) or email (via the `mail` MCP) with the open-incident summary.

## Thinking steps (apply these instead of trusting any cached list)

- **Confirm the tools are live first.** If an MCP call returns nothing or "tool not found," its server probably didn't load (common when the config changed after launch). Re-list its tools; if still missing, relaunch with the `--mcp` flags above rather than guessing the answer.
- **Resolve teams / services / owners live — never hardcode IDs.** Look them up each time with `get_teams_by_name`, `get_teams_by_public_id`, `get_services_by_names`. Watch for: display name ≠ publicId (tenant prefixes like `ENTERPRISESYDNEY\…` vs `COMPLIANTSYDNEY\…`), and informal **codenames** that aren't real ICM names — a "route to X team" note is a hint, not a destination, so resolve it via ServiceTree / Teams / a quick search before transferring.
- **Search by owning service, not a single team.** The `Word Copilot` service spans several teams (Triage, Prompt Assistance, …); a service-wide `search_incidents` surfaces items a per-team filter misses. Page through when the result window truncates.
- **Find the subject-matter expert from the monitor** Monitor-fired incidents carry a **monitor GUID** in the `monitorId` field of `get_incident_details_by_id` (also echoed in the mitigation text and the `resource://…` path). Customer-reported or manually-opened incidents won't have one — skip this path for those. For CompliantSydney monitors, search the **MonitorsCompSyd** repo for that GUID to find the monitor-definition file, then read that file's **PR history (creator + reviewers)** — those are the people who own the monitor and the experts to route to. Note the repo is in a **different ADO org** (`o365exchange` / project `O365 Core`, not `office`), so point an ado instance there (`--mcp "ado --organization o365exchange"`) or use the web UI / `git log` blame. Don't depend on a stored owner list (stale, and absent on a fresh machine).
- **State changes are out of band.** The `icm` MCP can investigate but **cannot ack / assign / transfer / mitigate** — do those in the IcM portal, or file and route an ADO bug for follow-up. Distinguish IcM **Mitigated** (impact stopped) from **Resolved** (terminal); 
- **Check the TSG wiki before anything destructive** — most recurring incidents have a documented mitigation; quote the section that applies.

## MCPs used

`icm` (incident triage, **read-only**), `ado` (work items), `kusto` (telemetry — AugLoop / Aria / 1ES clusters), `teams` / `mail` (handoff). Per-server args live behind `agency mcp <name> --help`.

## Notes

- Follow the response-time SLA in the OCE wiki for acks and mitigation comments.
- Don't auto-close or transfer an incident without confirming with the assigned engineer.
