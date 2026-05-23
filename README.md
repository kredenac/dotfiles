# Dotfiles

Personal configuration files for Windows development environment.
I'm testing these to be copied by the script which setups the fresh OS.

## What's tracked

| Tool | Config dir | Key settings |
|------|-----------|--------------|
| PowerShell | `$PROFILE` | Git aliases, posh-git, `COPILOT_ALLOW_ALL=true` |
| Windows Terminal | LocalState | Themes, profiles |
| Claude Code | `~/.claude/` | `settings.json`, `claude.md`, hooks, skills |
| **GitHub Copilot CLI** | `~/.copilot/` | `settings.json`, `mcp-config.json`, `permissions-config.json` |

## Setup

```powershell
git clone https://github.com/<you>/dotfiles C:\repos\dotfiles
cd C:\repos\dotfiles
.\setup.ps1
```

## Tips

### Copilot CLI "yolo" mode

Yolo mode (all permissions without prompts) is enabled via:
- `COPILOT_ALLOW_ALL=true` env var (set in profile and at User level)
- Equivalent to launching with `copilot --yolo` or `copilot --allow-all`
- No config file setting exists — the env var is the only way to persist it

### Trusted folders cover subdirectories

`trustedFolders` in `~/.copilot/config.json` uses prefix matching — adding `"C:\\"` trusts everything on the C drive. No need to add individual subdirs.

To add MCP servers, edit `.copilot/mcp-config.json`:
```json
{
  "mcpServers": {
    "my-server": {
      "command": "npx",
      "args": ["-y", "@some/mcp-server"]
    }
  }
}
```

