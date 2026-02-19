---
name: screenshot
description: Take a screenshot of the full screen and view it. Use when the user says "screenshot", "take a screenshot", "capture the screen", "show me what's on screen", or "/screenshot".
user_invocable: true
---

# screenshot

Capture a full-screen screenshot and view it.

## Steps

1. Run the screenshot script using the Bash tool:

```bash
powershell -ExecutionPolicy Bypass -File ~/.claude/scripts/screenshot.ps1
```

2. The script outputs the saved file path. Read the screenshot using the Read tool:

```
C:\Users\nidimitr\.claude\screenshots\latest.png
```

3. Describe what you see to the user, or answer any questions they have about the screen content.

## Notes

- The screenshot always overwrites `~/.claude/screenshots/latest.png` — only one file is ever kept.
- If the script fails, check that PowerShell is available and System.Windows.Forms is accessible.
