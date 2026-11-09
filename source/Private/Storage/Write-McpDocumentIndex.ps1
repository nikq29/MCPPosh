function Write-McpDocumentIndex {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $KbPath,

        [Parameter(Mandatory)]
        [string] $Id,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Content,

        [AllowEmptyString()]
        [string] $Title = ''
    )

    $paths = Get-McpDocumentPath -KbPath $KbPath -Id $Id
    $chunks = New-McpChunkIndex -Content $Content -Title $Title
    Write-McpJsonFile -Path $paths.Index -InputObject ([ordered]@{
            schemaVersion = 1
            id            = $Id
            chunks        = $chunks
        })
}
