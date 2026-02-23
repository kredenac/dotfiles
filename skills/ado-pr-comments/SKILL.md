---
name: ado-pr-comments
description: Fetch and display comments from an Azure DevOps pull request. Accepts a PR ID or full ADO URL.
user_invocable: true
allowed-tools: Bash(az *)
---

# ado-pr-comments

Fetch and display PR comments from Azure DevOps.

## Input

`$ARGUMENTS` is either:
- A PR number (e.g. `4892733`)
- A full ADO PR URL (e.g. `https://office.visualstudio.com/ISS/_git/augloop-workflows/pullrequest/4892733`)

If a URL is provided, extract the PR ID (last path segment), the org (scheme + host), and the project (first path segment after the host). If only a number is provided, use the defaults below.

### Defaults
- Org: `https://office.visualstudio.com`
- Project: `ISS`
- Repository: `augloop-workflows`

## Steps

1. **Ensure the `azure-devops` extension is installed** — run silently, ignore if already present:
   ```bash
   az extension add --name azure-devops --yes 2>/dev/null || true
   ```

2. **Fetch PR comment threads** using the REST API via `az devops invoke`:
   ```bash
   az devops invoke --area git --resource pullRequestThreads \
     --route-parameters project=<PROJECT> repositoryId=<REPO> pullRequestId=<PR_ID> \
     --org <ORG> --output json
   ```

3. **Parse the JSON response yourself** (do NOT use Python or any external script). From the JSON:
   - The threads are in the `value` array
   - Each thread has `status`, optional `threadContext.filePath`, and a `comments` array
   - Each comment has `commentType`, `author.displayName`, and `content`
   - **Skip** comments where `commentType` is `"system"` or `content` starts with `<!--`
   - For each remaining comment, note the thread status, file path (if any), author, and content

4. **Present the results** to the user in a readable list format showing:
   - Thread status (e.g. fixed, active, closed)
   - File path if the comment is on a specific file
   - Author name
   - Comment content (truncate very long comments)
   - Total comment count summary
