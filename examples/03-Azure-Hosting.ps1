<#
    Example 3: Host the MCP server centrally in Azure and maintain the knowledge locally with PowerShell.
    Requirements: Az PowerShell (Install-PSResource Az), the Bicep CLI and a container image
    (ghcr.io/<owner>/mcpposh:<version> from the release workflow, or built with az acr build).
#>
Import-Module MCPPosh
Connect-AzAccount

# 1. Deploy the infrastructure (Container App + Azure Files) and upload the knowledge base
$deployment = ./deploy/azure/deploy.ps1 -ResourceGroupName rg-mcpposh -Location westeurope `
    -Image ghcr.io/nikq29/mcpposh:latest -KnowledgeBase Contoso -Publish
$deployment | Format-List      # McpEndpoint, ApiKey (only for a generated key), storage

$endpoint = $deployment.McpEndpoint
$key = $deployment.ApiKey

# 2. Check the central server
Get-McpServer -Uri $endpoint -ApiKey $key | Format-List
Test-McpServer -Uri $endpoint -ApiKey $key -Query 'VPN'

# 3. Maintain knowledge locally and publish it (only changes are transferred)
Add-McpDocument -KnowledgeBase Contoso -Path C:\Docs\New -Recurse
Publish-McpKnowledgeBase -Name Contoso -StorageAccountName $deployment.StorageAccountName `
    -ShareName $deployment.ShareName -ResourceGroupName rg-mcpposh -Prune

# 4. Connect the agents of the team (do not share the key in plain text)
Get-McpClientConfig -KnowledgeBase Contoso -Client VSCode -Transport Http -Uri $endpoint -ApiKeyPlaceholder -AsJson
(Get-McpClientConfig -KnowledgeBase Contoso -Client ClaudeCode -Transport Http -Uri $endpoint -ApiKey $key).Command
