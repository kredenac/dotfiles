---
name: claude-cost
description: Calculate total API-equivalent cost of all Claude Code sessions on this PC. Use when the user asks about usage cost, token spend, or how much Claude Code has cost.
user-invokable: true
---

# claude-cost

Calculate and display the total API-equivalent cost of all Claude Code conversations on this machine.

## Steps

1. Run the cost calculator script:
   ```bash
   node "$USERPROFILE/.claude/scripts/claude-cost.mjs"
   ```
2. Present the output to the user as-is — the script already formats a table with per-model breakdowns and a grand total.
3. If the user asks for a specific date range, pass `--after YYYY-MM-DD`:
   ```bash
   node "$USERPROFILE/.claude/scripts/claude-cost.mjs" --after 2026-03-01
   ```
4. If the user wants a full rescan (ignoring the stats cache), pass `--no-cache`:
   ```bash
   node "$USERPROFILE/.claude/scripts/claude-cost.mjs" --no-cache
   ```

## Notes

- The script combines `~/.claude/stats-cache.json` (historical) with recent session JSONL files for a complete picture.
- Pricing is based on published Anthropic API rates. Subscription users pay a flat monthly fee instead.
- Runs in ~2 seconds normally. `--no-cache` is slower (~5-10s) as it parses all session files.
