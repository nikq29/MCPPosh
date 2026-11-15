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

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fnikq29%2FPSMcpKnowledgeBase%2Fmain%2Fdeploy%2Fazure%2Fazuredeploy.json/createUIDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2Fnikq29%2FPSMcpKnowledgeBase%2Fmain%2Fdeploy%2Fazure%2FcreateUiDefinition.json)

The button opens the template in the Azure portal: choose a subscription, a resource group and a region. On the
*Authentication* tab, pick one of the app registrations you own (or enter a client ID) to let users
[sign in with Microsoft Entra ID](#sign-in-with-microsoft-entra-id), and/or enter an API key of at least 16
characters. Adjust the other [template parameters](#template-parameters) on the *Options* tab if needed. The
image defaults to `ghcr.io/nikq29/psmcpkb:latest`; enter a fixed version such as `ghcr.io/nikq29/psmcpkb:0.1.1`
for production. The `mcpEndpoint` output of the deployment is the URL for the AI clients. To publish knowledge
afterwards, continue with [step 3](#3-publish-and-manage-knowledge).

With `deploy.ps1` you can deploy and publish in one step, and an API key is generated for you.
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
| `-OAuthClientId`, `-OAuthScope` | [Entra ID sign-in](#sign-in-with-microsoft-entra-id) with this app registration and scope | off, `access_as_user` |
| `-OAuthResource` | Application ID URI, only for a [custom domain](#custom-domain) | `https://<app>/mcp` |
| `-AllowAnonymous` | no API key is generated; only behind an authenticating gateway | off |
| `-AllowedOrigin` | browser origins allowed via CORS | none |
| `-MinReplicas` | minimum number of replicas (0 allows scale to zero) | `1` |
| `-Publish` | publishes the local knowledge base after the deployment | off |

The script returns `McpEndpoint`, `ApiKey` (only when generated), `StorageAccountName`, `ShareName` and
`ResourceGroupName` and prints the next steps.

Alternatively deploy the template with the Azure CLI:

```bash
az deployment group create -g rg-psmcpkb -f deploy/azure/main.bicep \
  -p apiKey=<at least 16 characters> knowledgeBase=Contoso
```

### Template parameters

| Parameter | Description | Default |
| --- | --- | --- |
| `name` | base name of all resources | `psmcpkb` |
| `location` | Azure region | resource group location |
| `image` | container image | `ghcr.io/nikq29/psmcpkb:latest` |
| `apiKey` | API key(s), comma-separated, at least 16 characters (secure); empty only with `oauthClientId` or `allowAnonymous` | empty |
| `oauthClientId` | client ID of an Entra app registration in the tenant; enables [OAuth sign-in](#sign-in-with-microsoft-entra-id) | empty |
| `oauthScope` | scope the app registration exposes | `access_as_user` |
| `oauthResource` | Application ID URI of the app registration, only for a [custom domain](#custom-domain) | `https://<app>/mcp` |
| `allowAnonymous` | no API key or token required; only behind an authenticating gateway | `false` |
| `knowledgeBase` | knowledge base name on the share | `Default` |
| `knowledgeBaseDescription` | description used when the knowledge base is created | empty |
| `allowWrite` | enables `add_note`; keep `maxReplicas` at 1 | `false` |
| `allowedOrigins` | comma-separated CORS origins | empty |
| `registryServer`, `registryUsername`, `registryPassword` | private registry credentials | empty |
| `minReplicas` | minimum replicas (0-10) | `1` |
| `maxReplicas` | maximum replicas (1-10) | `1` |
| `shareQuotaGiB` | quota of the file share | `5` |

Outputs: `mcpEndpoint` (`https://<app>/mcp`), `oauthApplicationIdUri` (with `oauthClientId`), `storageAccountName`
and `shareName`.

The issuer is the tenant you deploy to (`https://login.microsoftonline.com/<tenant id>/v2.0`); tokens must be issued
for `<client id>` (v2 tokens) and contain the scope `<oauthScope>`, which clients request as
`<oauthApplicationIdUri>/<oauthScope>`.

### Sign in with Microsoft Entra ID

One app registration serves as both the API and the client that signs users in:

1. *Microsoft Entra ID › App registrations › New registration*: single tenant, no redirect URI yet. Note the
   *Application (client) ID*. You are its owner, so the Deploy to Azure form lists it.
2. *Manifest*: set `requestedAccessTokenVersion` (older manifest format: `accessTokenAcceptedVersion`) to `2`. With
   v1 tokens the issuer does not match and every token is rejected. Entra ID requires this before step 4.
3. Deploy with `oauthClientId` (or `deploy.ps1 -OAuthClientId`).
4. *Expose an API*: set the Application ID URI to the output `oauthApplicationIdUri` (`https://<app>/mcp`, no
   trailing slash) and add the scope `access_as_user` (who can consent: admins and users). MCP clients send the
   endpoint URL as `resource` parameter; with any other Application ID URI, such as `api://<client id>`, Entra ID
   rejects the sign-in with AADSTS9010010.
5. *Authentication*: add the redirect URI of each client, for example
   - claude.ai: platform *Web*, `https://claude.ai/api/mcp/auth_callback`; create a client secret (*Certificates &
     secrets*) and enter client ID and secret in the advanced settings of the connector.
   - Claude Code: platform *Mobile and desktop applications*, `http://localhost:<port>/callback`, then
     `claude mcp add --transport http --client-id <client id> --callback-port <port> psmcpkb <mcpEndpoint>`.

With a [custom domain](#custom-domain) the Application ID URI is `https://<your domain>/mcp`: deploy again with
`oauthResource` (`deploy.ps1 -OAuthResource`) and change the URI of the app registration.

API keys keep working next to OAuth, for scripts and `Test-McpServer`.

### Custom domain

To serve the endpoint as `https://kb.contoso.com/mcp` instead of `https://<app>.azurecontainerapps.io/mcp`, add
the domain to the Container App with a free managed certificate:

1. Get the app's FQDN and domain verification ID:

   ```bash
   az containerapp show -n psmcpkb -g rg-psmcpkb \
     --query "{fqdn:properties.configuration.ingress.fqdn, id:properties.customDomainVerificationId}"
   ```

2. At your DNS provider, create `CNAME kb.contoso.com → <fqdn>` and `TXT asuid.kb.contoso.com → <id>`. For an apex
   domain, use an `A` record to the environment's IP (`az containerapp env show -n psmcpkb-env -g rg-psmcpkb
   --query properties.staticIp`) instead of the CNAME.
3. Add the hostname and bind it with a managed certificate (or in the portal: *Container App › Custom domains › Add
   custom domain › Managed certificate*):

   ```bash
   az containerapp hostname add  -n psmcpkb -g rg-psmcpkb --hostname kb.contoso.com
   az containerapp hostname bind -n psmcpkb -g rg-psmcpkb --hostname kb.contoso.com \
     --environment psmcpkb-env --validation-method CNAME
   ```

The default `azurecontainerapps.io` URL keeps working. OAuth needs no change: the server builds its protected
resource metadata from the host the client called. Browser clients need the new origin in `allowedOrigins`.
The template does not manage custom domains, so a redeploy of the template removes the binding; run step 3 again
afterwards.

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

- The Container App is only reachable over HTTPS; every call to `/mcp` requires the API key or an Entra ID access
  token. `/health` reports only the status without credentials and is used by the probes.
- Rotate keys without downtime: set the secret to `old-key,new-key`, update the clients, then remove the old key.
- Instead of the built-in Entra ID sign-in you can put Container Apps authentication ("Easy Auth") or Azure API
  Management in front of the app and set `allowAnonymous` only when the gateway authenticates every request.
- The server is stateless. Without write access you can increase `maxReplicas`; with `allowWrite` keep one replica.
- `minReplicas = 0` saves costs but causes a cold start of a few seconds on the first request.
- Logs: Log Analytics table `ContainerAppConsoleLogs_CL` or
  `az containerapp logs show -n psmcpkb -g rg-psmcpkb --follow`.
- Updates: `az containerapp update -n psmcpkb -g rg-psmcpkb --image ghcr.io/nikq29/psmcpkb:<new version>` creates a
  new revision and keeps all settings and the knowledge base on the share. Use a fixed version: with `:latest` the
  image name does not change and no new image is pulled. `deploy.ps1` also works, but pass `-ApiKey` and the OAuth
  parameters again; otherwise it generates a new API key and turns Entra ID sign-in off.
