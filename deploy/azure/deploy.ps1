<#
.SYNOPSIS
    Deploys PSMcpKnowledgeBase to Azure Container Apps and optionally publishes a local knowledge base.
.DESCRIPTION
    Requires the Az PowerShell modules (Az.Accounts, Az.Resources, Az.Storage) and the Bicep CLI
    (https://aka.ms/bicep-install). Creates or updates the resource group and all resources
    from main.bicep, then (with -Publish) uploads the local knowledge base to the file share.
.EXAMPLE
    ./deploy.ps1 -ResourceGroupName rg-psmcpkb -Image ghcr.io/nikq29/psmcpkb:latest -KnowledgeBase Contoso -Publish
.EXAMPLE
    ./deploy.ps1 -ResourceGroupName rg-psmcpkb -Image ghcr.io/nikq29/psmcpkb:latest -OAuthClientId 00000000-0000-0000-0000-000000000000

    Clients can sign in with Microsoft Entra ID (app registration in the current tenant) or use the generated API key.
.EXAMPLE
    ./deploy.ps1 -ResourceGroupName rg-psmcpkb -Image myacr.azurecr.io/psmcpkb:0.1.0 -RegistryServer myacr.azurecr.io -RegistryUsername myacr -RegistryPassword (Read-Host -AsSecureString)
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string] $ResourceGroupName,

    [string] $Location = 'westeurope',

    [ValidatePattern('^[a-z0-9-]{3,20}$')]
    [string] $Name = 'psmcpkb',

    [Parameter(Mandatory)]
    [string] $Image,

    # Generated when omitted. Shown once at the end; store it in a password manager.
    [string] $ApiKey,

    [string] $KnowledgeBase = 'Default',

    [string] $RegistryServer,

    [string] $RegistryUsername,

    [securestring] $RegistryPassword,

    [switch] $AllowWrite,

    # No API key is generated; only behind a gateway that authenticates every request.
    [switch] $AllowAnonymous,

    # Client ID of a Microsoft Entra app registration in the current tenant; enables OAuth sign-in.
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string] $OAuthClientId,

    [string] $OAuthScope = 'access_as_user',

    # Application ID URI of the app registration; only needed for a custom domain (https://kb.contoso.com/mcp).
    [string] $OAuthResource,

    [string[]] $AllowedOrigin,

    [ValidateRange(0, 10)]
    [int] $MinReplicas = 1,

    [switch] $Publish
)

$ErrorActionPreference = 'Stop'

foreach ($module in 'Az.Accounts', 'Az.Resources') {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        throw "The module '$module' is required: Install-Module Az -Scope CurrentUser"
    }
}
if (-not (Get-Command bicep -ErrorAction SilentlyContinue)) {
    throw 'The Bicep CLI is required for deploying main.bicep: https://aka.ms/bicep-install'
}
if (-not (Get-AzContext)) {
    Connect-AzAccount | Out-Null
}

if (-not $ApiKey -and -not $AllowAnonymous) {
    $bytes = [byte[]]::new(32)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    $ApiKey = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    $generatedKey = $true
}

$description = ''
if (Get-Module -ListAvailable -Name PSMcpKnowledgeBase) { Import-Module PSMcpKnowledgeBase }
if (Get-Command Get-McpKnowledgeBase -ErrorAction SilentlyContinue) {
    $localKb = Get-McpKnowledgeBase -Name $KnowledgeBase -ErrorAction SilentlyContinue
    if ($localKb) { $description = $localKb.Description }
}

$parameters = @{
    name                     = $Name
    location                 = $Location
    image                    = $Image
    apiKey                   = [string]$ApiKey
    knowledgeBase            = $KnowledgeBase
    knowledgeBaseDescription = $description
    allowWrite               = [bool]$AllowWrite
    allowAnonymous           = [bool]$AllowAnonymous
    allowedOrigins           = $AllowedOrigin -join ','
    minReplicas              = $MinReplicas
}
if ($OAuthClientId) {
    $parameters['oauthClientId'] = $OAuthClientId
    $parameters['oauthScope'] = $OAuthScope
    if ($OAuthResource) { $parameters['oauthResource'] = $OAuthResource }
}
if ($RegistryServer) {
    $parameters['registryServer'] = $RegistryServer
    $parameters['registryUsername'] = $RegistryUsername
    $parameters['registryPassword'] = [System.Net.NetworkCredential]::new('', $RegistryPassword).Password
}

if (-not $PSCmdlet.ShouldProcess($ResourceGroupName, "Deploy PSMcpKnowledgeBase ($Image)")) { return }

New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Force | Out-Null
$deployment = New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Name "psmcpkb-$(Get-Date -Format yyyyMMddHHmmss)" `
    -TemplateFile (Join-Path $PSScriptRoot 'main.bicep') -TemplateParameterObject $parameters

$endpoint = $deployment.Outputs['mcpEndpoint'].Value
$storageAccount = $deployment.Outputs['storageAccountName'].Value
$share = $deployment.Outputs['shareName'].Value

if ($Publish) {
    if (-not (Get-Command Publish-McpKnowledgeBase -ErrorAction SilentlyContinue)) {
        throw 'Import the PSMcpKnowledgeBase module to publish the knowledge base.'
    }
    Publish-McpKnowledgeBase -Name $KnowledgeBase -StorageAccountName $storageAccount -ShareName $share -ResourceGroupName $ResourceGroupName -Prune | Out-Host
}

[pscustomobject]@{
    McpEndpoint        = $endpoint
    ApiKey             = if ($generatedKey) { $ApiKey } elseif ($ApiKey) { '(as provided)' } else { '(none)' }
    StorageAccountName = $storageAccount
    ShareName          = $share
    ResourceGroupName  = $ResourceGroupName
}

Write-Host ''
Write-Host 'Next steps:' -ForegroundColor Cyan
if ($OAuthClientId) {
    Write-Host "  App registration > Expose an API: set the Application ID URI to $($deployment.Outputs['oauthApplicationIdUri'].Value)"
}
Write-Host "  Test-McpServer -Uri $endpoint -ApiKey <key>"
Write-Host "  Publish-McpKnowledgeBase -Name $KnowledgeBase -StorageAccountName $storageAccount -ShareName $share -ResourceGroupName $ResourceGroupName -Prune"
Write-Host "  Get-McpClientConfig -KnowledgeBase $KnowledgeBase -Client VSCode -Transport Http -Uri $endpoint -ApiKeyPlaceholder"
