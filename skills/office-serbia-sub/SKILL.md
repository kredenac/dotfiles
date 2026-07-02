---
name: office-serbia-sub
description: Manage RBAC on the "Office Serbia - External" Azure subscription — elevate access via PIM programmatically and add/remove role assignments. Use when asked to grant, remove, or audit owner/contributor access on the Office Serbia (aka "office serbia extended/external") Azure subscription, or to activate PIM elevation there.
user-invokable: true
---

# office-serbia-sub

Elevate access (PIM) and manage role assignments on the **Office Serbia - External** Azure subscription entirely from the CLI — no Azure Portal clicking required.

## What & where is it

- **Subscription name:** `Office Serbia - External` (people often call it "office serbia extended" — same thing; there is only one Serbia subscription).
- **Subscription ID:** `bfb5ed85-0322-4581-850a-62b1d508b0e4`
- **Tenant:** Microsoft (`72f988bf-86f1-41af-91ab-2d7cd011db47`)
- Owner @nidimitr has a **PIM-*eligible* Owner** role at the subscription scope that must be **activated** before reading or changing role assignments. Without activation, `az role assignment list` returns an empty `[]` (looks like "no permission", not an error).

## Critical gotcha: `az.bat` mangles `&` in URLs

PIM calls go through `az rest` with URLs containing `&$filter=...`. `az.bat` re-parses `&` as a cmd separator and breaks the call. **Always bypass the batch wrapper by invoking the CLI's Python module directly:**

```powershell
$py = "C:\Program Files\Microsoft SDKs\Azure\CLI2\python.exe"
& $py -IBm azure.cli <normal az args...>
```

Use `& $py -IBm azure.cli ...` for every `az rest` PIM call below. Plain `az ...` is fine for `role assignment list/delete/create` (no `&` in those).

Also: never name a PowerShell variable `$pid` (reserved/read-only). Use `$principal`, `$me`, etc.

## Steps

### 1. Confirm login
```powershell
az account show --query "{user:user.name, tenant:tenantId}" -o json
```

### 2. Activate PIM Owner (get access for 8 hours) — programmatic PIM

Set up:
```powershell
$py  = "C:\Program Files\Microsoft SDKs\Azure\CLI2\python.exe"
$sub = "bfb5ed85-0322-4581-850a-62b1d508b0e4"
$me  = (& $py -IBm azure.cli ad signed-in-user show --query id -o tsv)
```

Find your eligible Owner schedule ID (the `id`, from `roleEligibilitySchedules`, NOT the instances endpoint — using the instance name gives `RoleAssignmentDoesNotExist`):
```powershell
$url = 'https://management.azure.com/subscriptions/' + $sub + '/providers/Microsoft.Authorization/roleEligibilitySchedules?api-version=2020-10-01&$filter=asTarget()'
& $py -IBm azure.cli rest --method get --url $url --query "value[?properties.expandedProperties.roleDefinition.displayName=='Owner'].{id:id, roleDefId:properties.roleDefinitionId}" -o json
```

Self-activate for 8 hours (`PT8H`):
```powershell
$linked   = "<id from previous step>"     # /subscriptions/.../roleEligibilitySchedules/<guid>
$roleDef  = "/subscriptions/$sub/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635" # Owner
$reqId    = [guid]::NewGuid().ToString()
$start    = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
$body = @{ properties = @{
    principalId = $me
    roleDefinitionId = $roleDef
    requestType = "SelfActivate"
    linkedRoleEligibilityScheduleId = $linked
    justification = "<why you need access>"
    scheduleInfo = @{ startDateTime = $start; expiration = @{ type = "AfterDuration"; duration = "PT8H" } }
} } | ConvertTo-Json -Depth 10
$bodyFile = Join-Path $env:TEMP "pim_activate.json"
$body | Set-Content -Path $bodyFile -Encoding utf8
$url = "https://management.azure.com/subscriptions/$sub/providers/Microsoft.Authorization/roleAssignmentScheduleRequests/$reqId" + "?api-version=2020-10-01"
& $py -IBm azure.cli rest --method put --url $url --body "@$bodyFile" --query "{status:properties.status, role:properties.expandedProperties.roleDefinition.displayName}" -o json
```
Success = `status: Provisioned`. You now have Owner for 8 hours.

> If a PIM policy requires MFA/justification/ticket, the PUT returns an error describing what's missing — add it to the body (`justification`, `ticketInfo`) or complete MFA and retry.

### 3. Verify the activation is live
```powershell
$url = 'https://management.azure.com/subscriptions/' + $sub + "/providers/Microsoft.Authorization/roleAssignmentScheduleInstances?api-version=2020-10-01&`$filter=principalId eq '$me'"
& $py -IBm azure.cli rest --method get --url $url --query "value[].{role:properties.expandedProperties.roleDefinition.displayName, type:properties.assignmentType, start:properties.startDateTime, end:properties.endDateTime}" -o json
```
Look for `assignmentType: Activated` with an `end` ~8h out.

### 4. Find a person's assignments (active AND eligible, all scopes under the sub)

A person's Owner/Contributor may be **permanent (Assigned)** on a **resource group**, or **PIM-eligible** at the subscription — these don't show up in a plain subscription-scope `role assignment list`. Check all three:

```powershell
$person = (az ad user show --id "<alias>@microsoft.com" --query id -o tsv)

# Active/permanent RBAC directly at sub scope:
az role assignment list --scope "/subscriptions/$sub" --assignee $person --include-inherited -o table

# Active + PIM schedules (catches RG-scoped & activated roles) — shows the real scope:
$u = 'https://management.azure.com/subscriptions/' + $sub + "/providers/Microsoft.Authorization/roleAssignmentSchedules?api-version=2020-10-01&`$filter=principalId eq '$person'"
& $py -IBm azure.cli rest --method get --url $u --query "value[].{role:properties.expandedProperties.roleDefinition.displayName, type:properties.assignmentType, scope:properties.scope}" -o json

# PIM-eligible (not yet activated) assignments:
$u = 'https://management.azure.com/subscriptions/' + $sub + "/providers/Microsoft.Authorization/roleEligibilitySchedules?api-version=2020-10-01&`$filter=principalId eq '$person'"
& $py -IBm azure.cli rest --method get --url $u --query "value[].{role:properties.expandedProperties.roleDefinition.displayName, scope:properties.scope, name:name}" -o json
```

### 5. Remove a permanent (Assigned) role at its real scope
```powershell
$scope = "<scope from step 4, e.g. /subscriptions/$sub/resourceGroups/<rg>>"
az role assignment delete --assignee $person --role "Owner" --scope $scope
# verify:
az role assignment list --scope $scope --assignee $person -o table   # expect []
```

### 6. Remove a PIM-*eligible* assignment (AdminRemove)
If access is eligible (not active), delete the eligibility via `roleEligibilityScheduleRequests`:
```powershell
$eligDef = "<roleDefinitionId of the eligible role>"
$reqId = [guid]::NewGuid().ToString()
$body = @{ properties = @{
    principalId = $person
    roleDefinitionId = $eligDef
    requestType = "AdminRemove"
    justification = "Offboarding"
} } | ConvertTo-Json -Depth 10
$bodyFile = Join-Path $env:TEMP "pim_remove.json"; $body | Set-Content $bodyFile -Encoding utf8
$url = "https://management.azure.com/subscriptions/$sub/providers/Microsoft.Authorization/roleEligibilityScheduleRequests/$reqId" + "?api-version=2020-10-01"
& $py -IBm azure.cli rest --method put --url $url --body "@$bodyFile" -o json
```

## Glossary

- **IAM** (Identity & Access Management): the Azure **Access control (IAM)** blade where roles are assigned/viewed on a scope.
- **PIM** (Privileged Identity Management): just-in-time privileged access. You're *eligible* for a role and *activate* it temporarily instead of holding it permanently.
- **Eligible** vs **Active/Assigned**: eligible = must activate first; active/assigned = usable now (assigned = permanent, activated = temporary via PIM).

## Notes

- **Empty `[]` from `role assignment list` usually means "not elevated yet", not "no assignments"** — activate PIM (step 2) first.
- **Portal lag:** after activating via CLI, the Azure Portal IAM blade may still show the old view because the browser's access token caches role claims (~1h). Hard-refresh (Ctrl+F5), or sign out/in, or wait. The CLI/API is authoritative.
- Well-known role definition GUIDs: **Owner** `8e3af657-a8ff-443c-a75c-2fe8c4bcb635`, **Contributor** `b24988ac-6180-42a0-ab88-20f7382dd24c`, **Reader** `acdd72a7-3385-48ef-bd42-f606fba81ae7`.
- `asTarget()` filter = "my own" eligibilities; `principalId eq '<guid>'` = someone else's (needs Owner/User Access Administrator, i.e. do step 2 first).
- API version `2020-10-01` for all PIM (`roleEligibilitySchedules`, `roleAssignmentSchedules`, `role*ScheduleRequests`, `role*ScheduleInstances`).
