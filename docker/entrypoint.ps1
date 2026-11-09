<#
.SYNOPSIS
    Container entry point: prepares the knowledge base and runs the MCP server in the foreground.
.DESCRIPTION
    Configuration via environment variables:
      MCPPOSH_KNOWLEDGEBASE    Knowledge base name (default: Default)
      MCPPOSH_DESCRIPTION      Description used when the knowledge base is created
      MCPPOSH_PORT             Port (default: 8080)
      MCPPOSH_API_KEY          API key(s), comma-separated. Required unless MCPPOSH_ALLOW_ANONYMOUS=true
      MCPPOSH_ALLOW_WRITE      true = enable the add_note tool
      MCPPOSH_ALLOW_ANONYMOUS  true = no API key (only behind an authenticating gateway)
      MCPPOSH_ALLOWED_ORIGINS  Comma-separated browser origins for CORS
      MCPPOSH_IMPORT_PATH      Folder with documents to import on start (default: /seed if not empty)
      MCPPOSH_HOME             Data directory (default: /data, mount Azure Files here)
#>
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Test-Enabled([string] $Value) { $Value -match '^(1|true|yes|on)$' }

Import-Module MCPPosh

$knowledgeBase = if ($env:MCPPOSH_KNOWLEDGEBASE) { $env:MCPPOSH_KNOWLEDGEBASE } else { 'Default' }
$port = if ($env:MCPPOSH_PORT) { [int]$env:MCPPOSH_PORT } else { 8080 }

if (-not (Get-McpKnowledgeBase -Name $knowledgeBase -ErrorAction SilentlyContinue)) {
    Write-Host "Creating knowledge base '$knowledgeBase' in $env:MCPPOSH_HOME"
    New-McpKnowledgeBase -Name $knowledgeBase -Description ([string]$env:MCPPOSH_DESCRIPTION) | Out-Null
}

$importPath = if ($env:MCPPOSH_IMPORT_PATH) { $env:MCPPOSH_IMPORT_PATH } else { '/seed' }
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
if (Test-Enabled $env:MCPPOSH_ALLOW_WRITE) { $parameters['AllowWrite'] = $true }
if (Test-Enabled $env:MCPPOSH_ALLOW_ANONYMOUS) { $parameters['AllowAnonymous'] = $true }
if ($env:MCPPOSH_ALLOWED_ORIGINS) { $parameters['AllowedOrigin'] = $env:MCPPOSH_ALLOWED_ORIGINS -split ',' | ForEach-Object { $_.Trim() } }

Start-McpServer @parameters
