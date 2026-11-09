<#
.SYNOPSIS
    Deploys MCPPosh to Azure Container Apps and optionally publishes a local knowledge base.
.DESCRIPTION
    Requires the Az PowerShell modules (Az.Accounts, Az.Resources, Az.Storage) and the Bicep CLI
    (https://aka.ms/bicep-install). Creates or updates the resource group and all resources
    from main.bicep, then (with -Publish) uploads the local knowledge base to the file share.
.EXAMPLE
    ./deploy.ps1 -ResourceGroupName rg-mcpposh -Image ghcr.io/nikq29/mcpposh:latest -KnowledgeBase Contoso -Publish
.EXAMPLE
    ./deploy.ps1 -ResourceGroupName rg-mcpposh -Image myacr.azurecr.io/mcpposh:0.1.0 -RegistryServer myacr.azurecr.io -RegistryUsername myacr -RegistryPassword (Read-Host -AsSecureString)
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string] $ResourceGroupName,

    [string] $Location = 'westeurope',

    [ValidatePattern('^[a-z0-9-]{3,20}$')]
    [string] $Name = 'mcpposh',

    [Parameter(Mandatory)]
    [string] $Image,

    # Generated when omitted. Shown once at the end; store it in a password manager.
    [string] $ApiKey,

    [string] $KnowledgeBase = 'Default',

    [string] $RegistryServer,

    [string] $RegistryUsername,

    [securestring] $RegistryPassword,

    [switch] $AllowWrite,

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

if (-not $ApiKey) {
    $bytes = [byte[]]::new(32)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    $ApiKey = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    $generatedKey = $true
}

$description = ''
if (Get-Module -ListAvailable -Name MCPPosh) { Import-Module MCPPosh }
if (Get-Command Get-McpKnowledgeBase -ErrorAction SilentlyContinue) {
    $localKb = Get-McpKnowledgeBase -Name $KnowledgeBase -ErrorAction SilentlyContinue
    if ($localKb) { $description = $localKb.Description }
}

$parameters = @{
    name                     = $Name
    location                 = $Location
    image                    = $Image
    apiKey                   = $ApiKey
    knowledgeBase            = $KnowledgeBase
    knowledgeBaseDescription = $description
    allowWrite               = [bool]$AllowWrite
    minReplicas              = $MinReplicas
}
if ($RegistryServer) {
    $parameters['registryServer'] = $RegistryServer
    $parameters['registryUsername'] = $RegistryUsername
    $parameters['registryPassword'] = [System.Net.NetworkCredential]::new('', $RegistryPassword).Password
}

if (-not $PSCmdlet.ShouldProcess($ResourceGroupName, "Deploy MCPPosh ($Image)")) { return }

New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Force | Out-Null
$deployment = New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Name "mcpposh-$(Get-Date -Format yyyyMMddHHmmss)" `
    -TemplateFile (Join-Path $PSScriptRoot 'main.bicep') -TemplateParameterObject $parameters

$endpoint = $deployment.Outputs['mcpEndpoint'].Value
$storageAccount = $deployment.Outputs['storageAccountName'].Value
$share = $deployment.Outputs['shareName'].Value

if ($Publish) {
    if (-not (Get-Command Publish-McpKnowledgeBase -ErrorAction SilentlyContinue)) {
        throw 'Import the MCPPosh module to publish the knowledge base.'
    }
    Publish-McpKnowledgeBase -Name $KnowledgeBase -StorageAccountName $storageAccount -ShareName $share -ResourceGroupName $ResourceGroupName -Prune | Out-Host
}

[pscustomobject]@{
    McpEndpoint        = $endpoint
    ApiKey             = if ($generatedKey) { $ApiKey } else { '(as provided)' }
    StorageAccountName = $storageAccount
    ShareName          = $share
    ResourceGroupName  = $ResourceGroupName
}

Write-Host ''
Write-Host 'Next steps:' -ForegroundColor Cyan
Write-Host "  Test-McpServer -Uri $endpoint -ApiKey <key>"
Write-Host "  Publish-McpKnowledgeBase -Name $KnowledgeBase -StorageAccountName $storageAccount -ShareName $share -ResourceGroupName $ResourceGroupName -Prune"
Write-Host "  Get-McpClientConfig -KnowledgeBase $KnowledgeBase -Client VSCode -Transport Http -Uri $endpoint -ApiKeyPlaceholder"
