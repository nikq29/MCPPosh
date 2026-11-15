# Hosting in Azure

The Bicep template in [`deploy/azure`](../deploy/azure) runs a PSMcpKnowledgeBase server as an **Azure Container App**.
The knowledge base lives on an **Azure Files share** that the container mounts at `/data`. You keep maintaining the
knowledge locally with PowerShell and upload it with `Publish-McpKnowledgeBase`; the running server loads new
documents automatically.

```text
 PowerShell (local)                         Azure
 ┌─────────────────────┐   Publish-     ┌──────────────────────┐      ┌───────────────────────┐
 │ Add-McpDocument ... │──Mcp─────────► │ Azure Files (/data)  │◄─────│ Container App PSMcpKnowledgeBase │◄── AI agents
 │ knowledge base      │  KnowledgeBase │ knowledgebases/<KB>  │ mount│ https://…/mcp         │   (HTTPS +
 └─────────────────────┘                └──────────────────────┘      └───────────────────────┘    API key)
```

## Resources

| Resource | Configuration |
| --- | --- |
| Log Analytics workspace `<name>-logs` | PerGB2018, 30 days retention |
| Storage account | Standard_LRS, TLS 1.2, HTTPS only, no public blob access |
| Azure Files share `psmcpkb` | quota `shareQuotaGiB` (default 5 GiB) |
| Container Apps environment `<name>-env` | logs to Log Analytics, share registered as storage `psmcpkb-data` |
| Container App `<name>` | external HTTPS ingress to port 8080, 0.5 vCPU / 1 GiB, API key as secret, startup and liveness probes on `/health`, share mounted at `/data` with uid/gid 1654 |

## 1. Container image

Use the released image `ghcr.io/nikq29/psmcpkb:<version>` (built by the release workflow with PSMcpKnowledgeBase from the
PowerShell Gallery), or build your own image in an Azure Container Registry:

```powershell
az acr create -g rg-psmcpkb -n myacr --sku Basic --admin-enabled true
az acr build -r myacr -t psmcpkb:0.1.0 -f docker/Dockerfile --build-arg PSMCPKB_VERSION=0.1.0 .
```

## 2. Deploy

Requirements: Az PowerShell (`Install-PSResource Az`) and the [Bicep CLI](https://aka.ms/bicep-install).

```powershell
Connect-AzAccount
./deploy/azure/deploy.ps1 -ResourceGroupName rg-psmcpkb -Location westeurope `
    -Image ghcr.io/nikq29/psmcpkb:latest -KnowledgeBase Contoso -Publish
```

`deploy.ps1` parameters:

| Parameter | Description | Default |
| --- | --- | --- |
| `-ResourceGroupName` | resource group, created when it does not exist | required |
| `-Location` | Azure region | `westeurope` |
| `-Name` | base name of the resources (3-20 lowercase letters, digits, hyphens) | `psmcpkb` |
| `-Image` | container image | required |
| `-ApiKey` | API key; a random key is generated and shown once when omitted | generated |
| `-KnowledgeBase` | knowledge base to serve; its local description is used | `Default` |
| `-RegistryServer`, `-RegistryUsername`, `-RegistryPassword` | credentials for a private registry | none |
| `-AllowWrite` | enables the `add_note` tool | off |
| `-MinReplicas` | minimum number of replicas (0 allows scale to zero) | `1` |
| `-Publish` | publishes the local knowledge base after the deployment | off |

The script returns `McpEndpoint`, `ApiKey` (only when generated), `StorageAccountName`, `ShareName` and
`ResourceGroupName` and prints the next steps.

Alternatively deploy the template with the Azure CLI:

```bash
az deployment group create -g rg-psmcpkb -f deploy/azure/main.bicep \
  -p image=ghcr.io/nikq29/psmcpkb:latest apiKey=<at least 16 characters> knowledgeBase=Contoso
```

### Template parameters

| Parameter | Description | Default |
| --- | --- | --- |
| `name` | base name of all resources | `psmcpkb` |
| `location` | Azure region | resource group location |
| `image` | container image | required |
| `apiKey` | API key(s), comma-separated, at least 16 characters (secure) | required |
| `knowledgeBase` | knowledge base name on the share | `Default` |
| `knowledgeBaseDescription` | description used when the knowledge base is created | empty |
| `allowWrite` | enables `add_note`; keep `maxReplicas` at 1 | `false` |
| `allowedOrigins` | comma-separated CORS origins | empty |
| `registryServer`, `registryUsername`, `registryPassword` | private registry credentials | empty |
| `minReplicas` | minimum replicas (0-10) | `1` |
| `maxReplicas` | maximum replicas (1-10) | `1` |
| `shareQuotaGiB` | quota of the file share | `5` |

Outputs: `mcpEndpoint` (`https://<app>/mcp`), `storageAccountName` and `shareName`.

## 3. Publish and manage knowledge

```powershell
Add-McpDocument -KnowledgeBase Contoso -Path .\docs -Recurse
Publish-McpKnowledgeBase -Name Contoso -StorageAccountName <storage> -ShareName psmcpkb -ResourceGroupName rg-psmcpkb -Prune

Get-McpServer  -Uri https://<app>.azurecontainerapps.io/mcp -ApiKey $key   # status, documents, revision
Test-McpServer -Uri https://<app>.azurecontainerapps.io/mcp -ApiKey $key -Query 'VPN'
```

`Publish-McpKnowledgeBase` only uploads changed files and uploads the manifest last, so the server reloads only when
all files are in place. With `allowWrite`, it stops when the share holds agent notes that do not exist locally,
instead of removing them. See [Knowledge bases](knowledge-bases.md#publish-to-azure-files) for all options.

## 4. Connect AI clients

```powershell
Get-McpClientConfig -KnowledgeBase Contoso -Client VSCode     -Transport Http -Uri https://<app>.azurecontainerapps.io/mcp -ApiKeyPlaceholder
Get-McpClientConfig -KnowledgeBase Contoso -Client ClaudeCode -Transport Http -Uri https://<app>.azurecontainerapps.io/mcp -ApiKey $key
```

See [Client configuration](client-configuration.md#http).

## Security and operations

- The Container App is only reachable over HTTPS; every call to `/mcp` requires the API key. `/health` reports only
  the status without a key and is used by the probes.
- Rotate keys without downtime: set the secret to `old-key,new-key`, update the clients, then remove the old key.
- For Microsoft Entra ID, put Container Apps authentication ("Easy Auth") or Azure API Management in front of the
  app and set `PSMCPKB_ALLOW_ANONYMOUS=true` only when the gateway authenticates every request.
- The server is stateless. Without write access you can increase `maxReplicas`; with `allowWrite` keep one replica.
- `minReplicas = 0` saves costs but causes a cold start of a few seconds on the first request.
- Logs: Log Analytics table `ContainerAppConsoleLogs_CL` or
  `az containerapp logs show -n psmcpkb -g rg-psmcpkb --follow`.
- Updates: deploy a new image version with `deploy.ps1 -Image ghcr.io/nikq29/psmcpkb:<new version>`; the knowledge
  base on the share is kept.
