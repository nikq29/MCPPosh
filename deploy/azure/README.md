# Hosting MCPPosh centrally in Azure

This template runs an MCPPosh server as an **Azure Container App**. The knowledge base lives on an
**Azure Files share** that the container mounts at `/data`. You keep maintaining the knowledge
locally with PowerShell and upload it with `Publish-McpKnowledgeBase`. The running server loads new
documents automatically, no restart is needed.

```
 PowerShell (local)                         Azure
 ┌─────────────────────┐   Publish-     ┌──────────────────────┐      ┌───────────────────────┐
 │ Add-McpDocument ... │──Mcp─────────► │ Azure Files (/data)  │◄─────│ Container App MCPPosh │◄── AI agents
 │ knowledge base      │  KnowledgeBase │ knowledgebases/<KB>  │ mount│ https://…/mcp         │   (HTTPS +
 └─────────────────────┘                └──────────────────────┘      └───────────────────────┘    API key)
```

## Contents

| File | Purpose |
| --- | --- |
| `main.bicep` | Log Analytics, storage account with the share `mcpposh`, Container Apps environment, Container App with HTTPS ingress, API key secret and health probes |
| `deploy.ps1` | Deployment with Az PowerShell, optionally publishing the knowledge base right away |
| `../../docker/Dockerfile` | Container image (PowerShell 7.4, MCPPosh installed from the PowerShell Gallery, runs as a non-root user) |

## 1. Container image

**Option A: GitHub Container Registry (recommended).** The workflow `.github/workflows/build.yml`
builds `ghcr.io/<owner>/mcpposh:<version>` (and `:latest`) for every release tag `vX.Y.Z`, with
MCPPosh installed from the PowerShell Gallery. If the package is public, the Container App needs
no registry credentials.

**Option B: Azure Container Registry.**

```powershell
az acr create -g rg-mcpposh -n myacr --sku Basic --admin-enabled true
az acr build -r myacr -t mcpposh:0.1.0 -f docker/Dockerfile --build-arg MCPPOSH_VERSION=0.1.0 .
```

## 2. Deploy

```powershell
Install-PSResource -Name Az, MCPPosh    # once
Connect-AzAccount

./deploy/azure/deploy.ps1 -ResourceGroupName rg-mcpposh -Location westeurope `
    -Image ghcr.io/<owner>/mcpposh:latest -KnowledgeBase Contoso -Publish
```

For a private ACR image add `-RegistryServer myacr.azurecr.io -RegistryUsername myacr -RegistryPassword (Read-Host -AsSecureString)`.

Without `-ApiKey` the script generates a random key and shows it **once**. Alternatively with the
Azure CLI:

```bash
az deployment group create -g rg-mcpposh -f deploy/azure/main.bicep \
  -p image=ghcr.io/<owner>/mcpposh:latest apiKey=<at least 16 characters> knowledgeBase=Contoso
```

## 3. Publish and manage knowledge

```powershell
Add-McpDocument -KnowledgeBase Contoso -Path .\docs -Recurse
Publish-McpKnowledgeBase -Name Contoso -StorageAccountName <storage> -ShareName mcpposh -ResourceGroupName rg-mcpposh -Prune

Get-McpServer  -Uri https://<app>.azurecontainerapps.io/mcp -ApiKey $key   # status, documents, revision
Test-McpServer -Uri https://<app>.azurecontainerapps.io/mcp -ApiKey $key -Query 'VPN'
```

`Publish-McpKnowledgeBase` only uploads changed files and always uploads the manifest last.
`-Prune` removes documents that were deleted locally. Instead of `-ResourceGroupName` you can use
`-StorageAccountKey`, `-SasToken` or `-Context`.

Alternatively mount the share as a drive (SMB, port 445) and set `$env:MCPPOSH_HOME` to it; all
cmdlets then work directly on the central knowledge base.

## 4. Connect AI clients

```powershell
Get-McpClientConfig -KnowledgeBase Contoso -Client VSCode     -Transport Http -Uri https://<app>.azurecontainerapps.io/mcp -ApiKeyPlaceholder
Get-McpClientConfig -KnowledgeBase Contoso -Client ClaudeCode -Transport Http -Uri https://<app>.azurecontainerapps.io/mcp -ApiKey $key
```

Claude Desktop adds remote servers under *Settings › Connectors*, or through the `mcp-remote`
bridge (Node.js) created by `Get-McpClientConfig -Client ClaudeDesktop -Transport Http`.

## Container configuration

| Variable | Meaning | Default |
| --- | --- | --- |
| `MCPPOSH_API_KEY` | API key(s), comma-separated (secret) | required |
| `MCPPOSH_KNOWLEDGEBASE` | name of the knowledge base on the share | `Default` |
| `MCPPOSH_DESCRIPTION` | description used when the knowledge base is created | empty |
| `MCPPOSH_ALLOW_WRITE` | `true` enables the tool `add_note` | `false` |
| `MCPPOSH_ALLOWED_ORIGINS` | CORS origins for browser clients | empty |
| `MCPPOSH_ALLOW_ANONYMOUS` | `true` = no API key (only behind an authenticating gateway) | `false` |
| `MCPPOSH_IMPORT_PATH` | folder whose documents are imported at start | `/seed` |
| `MCPPOSH_PORT` | port inside the container | `8080` |

Image build arguments: `MCPPOSH_VERSION` (module version from the Gallery, empty = latest stable),
`MCPPOSH_SOURCE` (`PSGallery` or `Local` for packages in `docker/packages`) and `PWSH_VERSION`.

## Security and operations

- The Container App is only reachable over HTTPS. Every call to `/mcp` requires the API key
  (`Authorization: Bearer …` or `X-API-Key`). `/health` only shows the status without a key.
- Several keys (comma-separated) allow key rotation without downtime.
- For Microsoft Entra ID, put Container Apps authentication ("Easy Auth") or Azure API Management in
  front of the app, possibly with `MCPPOSH_ALLOW_ANONYMOUS=true`.
- The server is stateless. Without write access `maxReplicas` can be increased; with `allowWrite`
  keep a single replica.
- `minReplicas = 0` saves costs but causes a cold start of a few seconds.
- Logs: Log Analytics (`ContainerAppConsoleLogs_CL`) or `az containerapp logs show -n mcpposh -g rg-mcpposh --follow`.
