# Claude Code Tips

## Permissions
Use liberal permissions in `settings.json` to minimize confirmation prompts and keep Claude moving fast. The less it has to stop and ask, the more productive your sessions are.

## Split Terminals
Run Claude Code in split terminals in Windows Terminal. This lets you run multiple agents or keep a reference session open side-by-side.

## Image Pasting
Use **Alt+V** to paste images (screenshots, diagrams, UI mockups) directly into Claude Code. Regular Ctrl+V is reserved for text paste, so Alt+V is the dedicated image shortcut.

## Model & Effort
Use `/model` to switch to a higher-capability model and adjust effort level mid-conversation. Higher effort = more thorough reasoning on harder problems.

## Give It Verification Tools
Always give Claude a way to verify its own work so it can iterate autonomously. For example, use the Playwright MCP server for UI work so it can actually see and test what it builds. The tighter the feedback loop, the better the output.

## Voice Input
Use **Win+H** to activate Windows speech-to-text. Great for giving Claude a full brain dump of context, requirements, or stream-of-consciousness direction without typing it all out.

## Terminal Navigation (Windows Terminal)
- **Ctrl+Shift+Up/Down** — scroll the terminal buffer line by line without leaving your input line
- **Ctrl+Shift+M** — enter **Mark Mode**, which lets you move a cursor freely through the entire buffer (including old output above) using arrow keys. Hold **Shift** to select, then **Enter** to copy. Essential for mouseless terminal use.
- **Alt+Arrow keys** — switch focus between split panes
