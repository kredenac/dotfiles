## Coding Style
- Add comments only when logic isn't self-evident
- Never add obvious comments that just restate the next line (e.g. `// Channel interface` above `export interface Channel`)
- Use JSDoc (`/** */`) over `//` for documenting exports, interfaces, and public APIs

## Communication Preferences
- Be concise; skip fluff and get to the point
- Prefer commit names over commit hashes when referring to commits

## Agency MCP Toggling
- Enable an MCP globally: `agency config set --global --mcp <name>`
- Disable an MCP globally: `agency config set --global mcps.builtins.<name> false`
- Edit config interactively: `agency config edit --global` or `agency config tui`
- No dedicated toggle command exists; enable with `--mcp`, disable by setting the dot path to `false`
