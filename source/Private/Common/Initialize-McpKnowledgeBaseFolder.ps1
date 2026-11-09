function Initialize-McpKnowledgeBaseFolder {
    <#
    .SYNOPSIS
        Creates the folder structure and metadata of a knowledge base.

    .DESCRIPTION
        Creates the documents, index and logs folders of a knowledge base and writes knowledgebase.json and an empty manifest.json when they do not exist yet. Existing files are not changed.

    .PARAMETER Path
        Directory of the knowledge base. It is created together with its subfolders when needed.

    .PARAMETER Name
        Name of the knowledge base that is stored in knowledgebase.json.

    .PARAMETER Description
        Description of the knowledge base that is stored in knowledgebase.json and sent to AI agents.

    .EXAMPLE
        Initialize-McpKnowledgeBaseFolder -Path (Join-Path (Get-McpKnowledgeBaseRoot) 'Contoso') -Name Contoso -Description 'Contoso IT documentation'

        Creates the knowledge base Contoso in the default location.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [string] $Name,

        [AllowEmptyString()]
        [string] $Description = ''
    )

    foreach ($sub in '', 'documents', 'index', 'logs') {
        $dir = if ($sub) { Join-Path -Path $Path -ChildPath $sub } else { $Path }
        if (-not [System.IO.Directory]::Exists($dir)) {
            $null = [System.IO.Directory]::CreateDirectory($dir)
        }
    }

    $now = Get-McpUtcNow
    $metaPath = Join-Path -Path $Path -ChildPath 'knowledgebase.json'
    if (-not (Test-Path -LiteralPath $metaPath)) {
        Write-McpJsonFile -Path $metaPath -InputObject ([ordered]@{
                schemaVersion = 1
                name          = $Name
                description   = $Description
                created       = $now
            })
    }
    $manifestPath = Join-Path -Path $Path -ChildPath 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        Write-McpJsonFile -Path $manifestPath -InputObject ([ordered]@{
                schemaVersion = 1
                revision      = 0
                updated       = $now
                documents     = @()
            })
    }
}
