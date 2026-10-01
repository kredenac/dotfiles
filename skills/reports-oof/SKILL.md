---
name: reports-oof
description: Check direct reports' OOF dates in MS Vacation. Use for /reports-oof, "reports OOF", "who is out", or current-and-next-month team vacation checks.
---

# reports-oof

Read the authenticated MS Vacation manager calendar and summarize each direct report's OOF dates.

## Steps

1. Run:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File C:\repos\dotfiles\scripts\reports-oof.ps1
   ```

2. Return the command's report directly. Keep every direct report in the list, including people with no OOF.
3. If the user specifies a different start date or number of calendar months, pass `-StartDate YYYY-MM-DD` and `-Months N`.
4. If authentication fails, run the script once with `-Setup`, ask the user to complete sign-in in the dedicated Edge window, and then rerun normally.

## Rules

- Default to today through the end of next month.
- Include only immediate reports from the manager hierarchy, not the manager or deeper descendants.
- Merge OOF days across weekends.
- Ignore standalone `PH` public holidays. A `PH` may bridge a range only when OOF days occur on both sides.
- Mark pending or mixed approval ranges; otherwise report approved OOF without extra status text.

## Notes

- The script uses a dedicated local Edge profile at `%LOCALAPPDATA%\reports-oof\EdgeProfile` so repeat calls are fast.
- It reads MS Vacation only and does not submit or change requests.
