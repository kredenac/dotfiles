---
name: direct-reports-pulse
description: Generate Dimi's lightweight weekly engineering report for his direct reports. Use for `/direct-reports-pulse`, "generate my direct reports report", "team pulse", "weekly team stats", or "show engineering activity for my directs".
user-invokable: true
---

# direct-reports-pulse

Generate a concise weekly engineering pulse for Dimi's current direct reports from Azure DevOps and GitHub EMU telemetry.

## Steps

1. Sync and read `C:\repos\octo-memory\MEMORY.md` and `C:\repos\octo-memory\team.md` with the `octo-memory` skill. Treat the **Direct Reports** table as the expected roster and preserve leave notes.
2. Use `C:\repos\engpulse`. If it is absent, clone `https://msft.ghe.com/outlook/engpulse`. Read its `.github\copilot-instructions.md`, `skills\generate-report\SKILL.md`, and `docs\running-the-report.md` before running anything.
3. Default the window to the most recent complete Monday-Sunday week. Accept an explicit `<START>_<END>` window from the user.
4. Verify Azure CLI authentication, Python, and read access to the `AzureDevOps`, `AzureActiveDirectory`, and `GitHub.EMU` databases on `https://1es.westus2.kusto.windows.net`. Do not run EngPulse's full preflight because this report intentionally excludes `GitHub.Proxima`. Stop and report the exact missing required grant instead of substituting other data.
5. Query the latest `AzureActiveDirectory.AADUser` rows and select employees whose `ReportsToEmailName` equals `nidimitr`, excluding guests and service accounts. Compare the result with `team.md`:
   - Use AAD as the current membership source.
   - Use `team.md` for aliases, leave status, GitHub identities, and display notes.
   - Show additions, removals, or alias mismatches before the metrics.
   - Never silently include former reports or close partners.
6. Query PR rows directly from `AzureDevOps.PullRequest` and `GitHub.EMU.PullRequest` for the report week plus the three preceding weeks. Resolve GitHub authors through the latest `GitHub.EMU.User` row and Microsoft email alias. When a current or historical Microsoft email does not normalize to the ADO alias, reconcile it only through an exact GitHub identity recorded in `team.md`; list identities that still cannot be resolved. Never reference `GitHub.Proxima`; `msft.ghe.com` activity is outside this report's declared scope.
7. Retain rows whose normalized author alias matches the verified direct-report aliases. Deduplicate ADO rows by organization, repository ID, and PR ID, and GitHub rows by hostname, organization ID, repository ID, and PR ID using the latest ETL row. Keep default/trunk-target PRs, apply `config\trunk-branches.json`, and classify title chores with EngPulse's `scripts\shared\chore_filter.py`. Exclude chores from headline metrics.
8. Produce a compact Markdown report with exactly these sections:
   1. **Roster changes** - only when AAD and `team.md` differ.
   2. **Team snapshot** - opened PRs, merged PRs, merge rate, active contributors, merged PRs per active contributor, median time to merge, and P80 time to merge. Show the report week and trailing four weeks side by side.
   3. **By direct report** - person, area, opened, merged, active PRs, median time to merge, and top repositories. Include zero-activity and leave rows; do not rank people or apply red/green performance labels.
   4. **Notable work** - 3-7 evidence-backed themes derived from PR titles and descriptions, with PR links. Separate facts from interpretation.
   5. **Data notes** - EngPulse source commit, window, included databases, explicit Proxima exclusion, filters, and missing identities.
9. Compute time-to-merge from PR creation to merge/closure, subtracting weekend hours with EngPulse's UTC weekend convention. Label it **creation-to-merge** so it is not confused with EngPulse's draft-aware publish-to-merge metric. Use nearest-rank lower median and P80. Display `n/a` when the sample is empty and include the sample size for percentile metrics.
10. Save the Markdown source to `%LOCALAPPDATA%\engpulse\direct-reports-pulse\<WINDOW>\direct-reports-pulse.md`, render a self-contained HTML copy beside it as `direct-reports-pulse.html`, and open the HTML file in the default browser with `Start-Process`. Return both paths and a three-sentence executive summary. Do not send or publish the report unless Dimi explicitly asks.

## Notes

- This report is a management activity pulse, not an individual performance scorecard.
- PR metrics cover Azure DevOps and `github.com` repositories represented in `GitHub.EMU`, including `opg-microsoft`. They intentionally exclude `msft.ghe.com`.
- Work-item and incident metrics are intentionally excluded because direct-report ownership cannot be inferred reliably from broad area paths.
- Query only verified direct-report aliases, not Dimi's full management chain.
- Do not edit KQL, EngPulse run-control settings, or report-server files.
- Do not commit generated reports or EngPulse cache data.
- Open the report only after the HTML file has been written successfully.
