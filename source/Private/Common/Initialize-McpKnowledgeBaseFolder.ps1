function Initialize-McpKnowledgeBaseFolder {
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
