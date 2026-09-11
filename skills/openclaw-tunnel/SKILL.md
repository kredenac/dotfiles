---
name: openclaw-tunnel
description: Start or restore the Kutak OpenClaw SSH tunnel and open the local Octo chat. Use when the user says "open OpenClaw", "open Octo chat", "start the OpenClaw tunnel", "localhost 18789 is unavailable", or "/openclaw-tunnel".
user-invokable: true
---

# openclaw-tunnel

Make the loopback-only OpenClaw Gateway in Kutak VM `102` available securely on Dimi-PC.

## Steps

1. Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\repos\kutak\scripts\start-openclaw-tunnel.ps1
```

2. Confirm that the script reports the chat URL. It opens the browser automatically.
3. If it fails, report the exact error. Verify `ssh openclaw` connectivity and that the Gateway is
   listening on `127.0.0.1:18789` inside VM `102`; do not expose port `18789` to the LAN.

## Notes

- The script is idempotent: it reuses a working local endpoint instead of starting another tunnel.
- The local URL is
  `http://127.0.0.1:18789/chat?session=agent%3Amain%3Amain`.
- Pass `-NoBrowser` when only the tunnel and endpoint check are needed.
- Never print, copy, or store the OpenClaw Gateway token.
