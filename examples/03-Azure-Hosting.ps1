<#
    Beispiel 3: Den MCP-Server zentral in Azure hosten und das Wissen lokal per PowerShell pflegen.
    Voraussetzungen: Az PowerShell (Install-Module Az), Bicep CLI, ein Container-Image
    (z. B. ghcr.io/<owner>/mcpposh:latest aus dem GitHub-Workflow oder per az acr build).
#>
Import-Module MCPPosh
Connect-AzAccount

# 1. Infrastruktur bereitstellen (Container App + Azure Files) und Wissensbasis hochladen
$deployment = ./deploy/azure/deploy.ps1 -ResourceGroupName rg-mcpposh -Location westeurope `
    -Image ghcr.io/nikq29/mcpposh:latest -KnowledgeBase Contoso -Publish
$deployment | Format-List      # McpEndpoint, ApiKey (nur bei automatisch erzeugtem Key), Storage

$endpoint = $deployment.McpEndpoint
$key = $deployment.ApiKey

# 2. Zentralen Server prüfen
Get-McpServer -Uri $endpoint -ApiKey $key | Format-List
Test-McpServer -Uri $endpoint -ApiKey $key -Query 'VPN'

# 3. Wissen lokal pflegen und veröffentlichen (nur Änderungen werden übertragen)
Add-McpDocument -KnowledgeBase Contoso -Path C:\Doku\Neu -Recurse
Publish-McpKnowledgeBase -Name Contoso -StorageAccountName $deployment.StorageAccountName `
    -ShareName $deployment.ShareName -ResourceGroupName rg-mcpposh -Prune

# 4. Agents im Team verbinden (Key nicht im Klartext verteilen)
Get-McpClientConfig -KnowledgeBase Contoso -Client VSCode -Transport Http -Uri $endpoint -ApiKeyPlaceholder -AsJson
(Get-McpClientConfig -KnowledgeBase Contoso -Client ClaudeCode -Transport Http -Uri $endpoint -ApiKey $key).Command
