<#
.SYNOPSIS
    Container entry point: prepares the knowledge base and runs the MCP server in the foreground.
.DESCRIPTION
    Configuration via environment variables:
      PSMCPKB_KNOWLEDGEBASE    Knowledge base name (default: Default)
      PSMCPKB_DESCRIPTION      Description used when the knowledge base is created
      PSMCPKB_PORT             Port (default: 8080)
      PSMCPKB_API_KEY          API key(s), comma-separated. Required unless PSMCPKB_ALLOW_ANONYMOUS=true
      PSMCPKB_ALLOW_WRITE      true = enable the add_note tool
      PSMCPKB_ALLOW_ANONYMOUS  true = no API key (only behind an authenticating gateway)
      PSMCPKB_ALLOWED_ORIGINS  Comma-separated browser origins for CORS
      PSMCPKB_IMPORT_PATH      Folder with documents to import on start (default: /seed if not empty)
      PSMCPKB_HOME             Data directory (default: /data, mount Azure Files here)
#>
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Test-Enabled([string] $Value) { $Value -match '^(1|true|yes|on)$' }

Import-Module PSMcpKnowledgeBase

$knowledgeBase = if ($env:PSMCPKB_KNOWLEDGEBASE) { $env:PSMCPKB_KNOWLEDGEBASE } else { 'Default' }
$port = if ($env:PSMCPKB_PORT) { [int]$env:PSMCPKB_PORT } else { 8080 }

if (-not (Get-McpKnowledgeBase -Name $knowledgeBase -ErrorAction SilentlyContinue)) {
    Write-Host "Creating knowledge base '$knowledgeBase' in $env:PSMCPKB_HOME"
    New-McpKnowledgeBase -Name $knowledgeBase -Description ([string]$env:PSMCPKB_DESCRIPTION) | Out-Null
}

$importPath = if ($env:PSMCPKB_IMPORT_PATH) { $env:PSMCPKB_IMPORT_PATH } else { '/seed' }
if ((Test-Path -LiteralPath $importPath) -and (Get-ChildItem -LiteralPath $importPath -Recurse -File | Select-Object -First 1)) {
    Write-Host "Importing documents from $importPath"
    $imported = @(Add-McpDocument -Path $importPath -Recurse -KnowledgeBase $knowledgeBase -ErrorAction Continue)
    Write-Host "Imported or updated $($imported.Count) document(s)"
}

$parameters = @{
    KnowledgeBase = $knowledgeBase
    Transport     = 'Http'
    Port          = $port
    ListenAddress = '*'
    Foreground    = $true
}
if (Test-Enabled $env:PSMCPKB_ALLOW_WRITE) { $parameters['AllowWrite'] = $true }
if (Test-Enabled $env:PSMCPKB_ALLOW_ANONYMOUS) { $parameters['AllowAnonymous'] = $true }
if ($env:PSMCPKB_ALLOWED_ORIGINS) { $parameters['AllowedOrigin'] = $env:PSMCPKB_ALLOWED_ORIGINS -split ',' | ForEach-Object { $_.Trim() } }

Start-McpServer @parameters
