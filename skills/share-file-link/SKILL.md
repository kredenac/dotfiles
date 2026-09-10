---
name: share-file-link
description: Create or copy a file into the active OneDrive/SharePoint sync folder and return a browser link. Use for /share-file-link, "share this file", "give me a link to this file", "put this text in a file and share it", or "create a OneDrive link".
user-invokable: true
---

# share-file-link

Turn an existing local file or supplied text/context into a synced OneDrive file and return its browser-accessible link.

## Steps

1. Determine which input the user supplied:
   - An existing local file path: use `-InputPath`.
   - Text or conversation context: use `-Text`. Choose a concise, descriptive `.md` filename unless the user supplied a filename.
2. If neither a file nor usable text/context is clear, ask for the missing input. Do not ask for a filename when a sensible one can be inferred.
3. Run `C:\repos\dotfiles\scripts\share-file-link.ps1`:

   ```powershell
   & 'C:\repos\dotfiles\scripts\share-file-link.ps1' -InputPath '<absolute-path>'
   ```

   Or for text:

   ```powershell
   & 'C:\repos\dotfiles\scripts\share-file-link.ps1' -Text '<content>' -FileName '<name>.md'
   ```

   Use `-DestinationFolder '<folder>'` only when the user requests a OneDrive subfolder other than the default `agent-docs`.
4. Read the script's `Path` and `Link` output. Return a Markdown link to the file and mention the synced local path.
5. If the script reports that OneDrive is not configured, the file did not sync, or Windows did not expose **Copy Link**, report that error directly. Never fabricate or derive a sharing URL manually.

## Notes

- The default destination is the `agent-docs` folder in the actively configured OneDrive account.
- Existing destination files are not overwritten unless the user explicitly requests replacement and the script is called with `-Force`.
- The generated link may require the recipient to sign in with an account that has access.
- This workflow depends on Windows, the OneDrive sync client, and the Explorer **Copy Link** action.
