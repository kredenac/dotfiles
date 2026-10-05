---
name: direct-reports-pulse
description: Generate a fast, deterministic five-week direct-reports engineering pulse for any manager alias.
---

# direct-reports-pulse

Generate the direct-reports pulse without invoking the full EngPulse conductor or report-writing agents.

## Input

- Manager alias or Microsoft email. Default to `nidimitr` only when Dimi invokes the skill without naming another manager.
- Optional output root. Default to `%LOCALAPPDATA%\engpulse\direct-reports-pulse`.

## Steps

1. Require a clean `C:\repos\dotfiles` checkout on `main`, then run `git pull --ff-only origin main`. Stop if this fails.
2. Require a clean `C:\repos\engpulse` checkout on `main`, then run `git pull --ff-only origin main`. Stop if this fails.
3. Run:

   ```powershell
   python C:\repos\dotfiles\skills\direct-reports-pulse\scripts\generate.py --manager <ALIAS>
   ```

   For `nidimitr`, also pass:

   ```powershell
   --team-file C:\repos\octo-agent\user-data\memory\team.md
   ```

4. Return the elapsed time, Markdown path, HTML path, and the command's executive summary.
5. Do not publish or send the report unless Dimi explicitly asks.

## Scope

- Tuesday-Sunday: current Monday-Sunday week-to-date plus four preceding complete weeks.
- Monday: the preceding complete Monday-Sunday week (the latest seven-day period) plus four earlier complete weeks, avoiding an empty one-day comparison.
- Azure DevOps and `GitHub.EMU` PR telemetry.
- `GitHub.Proxima` and `msft.ghe.com` are intentionally excluded.
- AAD is the roster source. The optional team file enriches names, leave notes, and known identity aliases.
- The script runs one AAD roster query followed by concurrent ADO and GitHub queries. Rendering is deterministic and does not call an LLM.
