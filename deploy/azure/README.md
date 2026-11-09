# MCPPosh zentral in Azure hosten

Diese Vorlage betreibt einen MCPPosh-Server als **Azure Container App**. Die Wissensbasis liegt auf
einer **Azure-Files-Freigabe**, die der Container unter `/data` einbindet. Gepflegt wird das Wissen
weiterhin lokal mit PowerShell und per `Publish-McpKnowledgeBase` hochgeladen. Der laufende Server
lädt neue Dokumente automatisch nach, ein Neustart ist nicht nötig.

```
 PowerShell (lokal)                         Azure
 ┌─────────────────────┐   Publish-     ┌──────────────────────┐      ┌───────────────────────┐
 │ Add-McpDocument ... │──Mcp─────────► │ Azure Files (/data)  │◄─────│ Container App MCPPosh │◄── AI-Agents
 │ Wissensbasis        │  KnowledgeBase │ knowledgebases/<KB>  │ mount│ https://…/mcp         │   (HTTPS +
 └─────────────────────┘                └──────────────────────┘      └───────────────────────┘    API-Key)
```

## Bestandteile

| Datei | Zweck |
| --- | --- |
| `main.bicep` | Log Analytics, Storage Account + Freigabe `mcpposh`, Container-Apps-Umgebung, Container App mit HTTPS-Ingress, API-Key als Secret und Health-Probes |
| `deploy.ps1` | Bereitstellung per Az PowerShell, optional direkt mit Veröffentlichung der Wissensbasis |
| `../../docker/Dockerfile` | Container-Image (PowerShell 7.4 + MCPPosh, läuft als Nicht-root-Benutzer) |

## 1. Image bauen

**Variante A: Azure Container Registry**

```powershell
az acr create -g rg-mcpposh -n meineacr --sku Basic --admin-enabled true
az acr build -r meineacr -t mcpposh:0.1.0 -f docker/Dockerfile .
```

**Variante B: GitHub Container Registry**: Der Workflow `.github/workflows/docker.yml` baut bei jedem
Push auf `main` und bei Tags `v*` automatisch `ghcr.io/<owner>/mcpposh`. Ist das Paket öffentlich,
braucht die Container App keine Registry-Zugangsdaten.

## 2. Bereitstellen

```powershell
Install-Module Az -Scope CurrentUser        # einmalig
Connect-AzAccount

./deploy/azure/deploy.ps1 -ResourceGroupName rg-mcpposh -Location westeurope `
    -Image ghcr.io/<owner>/mcpposh:latest -KnowledgeBase Contoso -Publish
```

Für ein privates ACR-Image zusätzlich `-RegistryServer meineacr.azurecr.io -RegistryUsername meineacr -RegistryPassword (Read-Host -AsSecureString)` angeben.

Ohne `-ApiKey` erzeugt das Skript einen zufälligen Schlüssel und zeigt ihn **einmal** an.
Alternativ mit der Azure CLI:

```bash
az deployment group create -g rg-mcpposh -f deploy/azure/main.bicep \
  -p image=ghcr.io/<owner>/mcpposh:latest apiKey=<mind. 16 Zeichen> knowledgeBase=Contoso
```

## 3. Wissen veröffentlichen und verwalten

```powershell
Add-McpDocument -KnowledgeBase Contoso -Path .\docs -Recurse
Publish-McpKnowledgeBase -Name Contoso -StorageAccountName <storage> -ShareName mcpposh -ResourceGroupName rg-mcpposh -Prune

Get-McpServer  -Uri https://<app>.azurecontainerapps.io/mcp -ApiKey $key   # Status, Dokumente, Revision
Test-McpServer -Uri https://<app>.azurecontainerapps.io/mcp -ApiKey $key -Query 'VPN'
```

`Publish-McpKnowledgeBase` lädt nur geänderte Dateien hoch, das Manifest immer zuletzt. `-Prune`
entfernt Dokumente, die lokal gelöscht wurden. Statt `-ResourceGroupName` gehen auch
`-StorageAccountKey`, `-SasToken` oder `-Context`.

Alternativ lässt sich die Freigabe als Laufwerk einbinden (SMB, Port 445). Setzt man
`$env:MCPPOSH_HOME` auf das Laufwerk, arbeiten alle Cmdlets direkt auf der zentralen Wissensbasis.

## 4. AI-Clients verbinden

```powershell
Get-McpClientConfig -KnowledgeBase Contoso -Client VSCode   -Transport Http -Uri https://<app>.azurecontainerapps.io/mcp -ApiKeyPlaceholder
Get-McpClientConfig -KnowledgeBase Contoso -Client ClaudeCode -Transport Http -Uri https://<app>.azurecontainerapps.io/mcp -ApiKey $key
```

Claude Desktop bindet entfernte Server über *Einstellungen › Connectors* ein oder über die von
`Get-McpClientConfig -Client ClaudeDesktop -Transport Http` erzeugte `mcp-remote`-Brücke (Node.js).

## Konfiguration des Containers

| Variable | Bedeutung | Standard |
| --- | --- | --- |
| `MCPPOSH_API_KEY` | API-Key(s), kommagetrennt (Secret) | Pflicht |
| `MCPPOSH_KNOWLEDGEBASE` | Name der Wissensbasis auf der Freigabe | `Default` |
| `MCPPOSH_DESCRIPTION` | Beschreibung beim ersten Anlegen | leer |
| `MCPPOSH_ALLOW_WRITE` | `true` aktiviert das Tool `add_note` | `false` |
| `MCPPOSH_ALLOWED_ORIGINS` | CORS-Origins für Browser-Clients | leer |
| `MCPPOSH_ALLOW_ANONYMOUS` | `true` = ohne API-Key (nur hinter einem authentifizierenden Gateway) | `false` |
| `MCPPOSH_IMPORT_PATH` | Ordner, dessen Dokumente beim Start importiert werden | `/seed` |
| `MCPPOSH_PORT` | Port im Container | `8080` |

## Sicherheit und Betrieb

- Die Container App ist nur per HTTPS erreichbar. Jeder Aufruf von `/mcp` braucht den API-Key
  (`Authorization: Bearer …` oder `X-API-Key`). `/health` zeigt ohne Key nur den Status.
- Mehrere Schlüssel (kommagetrennt) erlauben eine Rotation ohne Ausfall.
- Für Microsoft Entra ID lässt sich der Container-App-Authentifizierungsdienst („Easy Auth“) oder Azure
  API Management vorschalten, dann eventuell mit `MCPPOSH_ALLOW_ANONYMOUS=true`.
- Der Server ist zustandslos. Ohne Schreibzugriff kann `maxReplicas` erhöht werden. Mit
  `allowWrite` sollte es bei einer Replica bleiben.
- `minReplicas = 0` spart Kosten, verursacht aber einige Sekunden Kaltstart.
- Logs: Log Analytics (`ContainerAppConsoleLogs_CL`) oder `az containerapp logs show -n mcpposh -g rg-mcpposh --follow`.
