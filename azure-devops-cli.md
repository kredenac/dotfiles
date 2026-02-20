# Azure DevOps CLI Cheat Sheet

## Setup

```bash
# Install the extension
az extension add --name azure-devops

# Configure defaults (Office org, OC project)
az devops configure --defaults organization=https://office.visualstudio.com project=OC

# Auth: either `az login` (if AAD has ADO access) or set a PAT
export AZURE_DEVOPS_EXT_PAT=your-personal-access-token
```

## Common Commands

```bash
# Work items
az boards work-item show --id 12345
az boards query --wiql "SELECT [Id], [Title] FROM WorkItems WHERE [State] = 'Active'"

# Repos
az repos list
az repos pr list

# Pipelines
az pipelines list
az pipelines run show --id 123

# Backlogs
az boards query --wiql "SELECT [Id], [Title], [State] FROM WorkItems WHERE [System.TeamProject] = 'OC'"
```

## URL Format

`https://office.visualstudio.com/OC/...`
- **Organization**: `office` (older format, still works — equivalent to `dev.azure.com/office`)
- **Project**: `OC`
