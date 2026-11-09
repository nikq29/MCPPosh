function Write-McpDocumentIndex {
    <#
    .SYNOPSIS
        Builds and writes the search index file of a document.

    .DESCRIPTION
        Splits the document into chunks with New-McpChunkIndex, computes their term frequencies and writes them to index/<id>.json, which the BM25 search loads.

    .PARAMETER KbPath
        Directory of the knowledge base that contains the document.

    .PARAMETER Id
        Id of the document, used as the file name of the index file.

    .PARAMETER Content
        The normalized Markdown content of the document to index.

    .PARAMETER Title
        Title of the document; its terms are added to every chunk of the document.

    .EXAMPLE
        Write-McpDocumentIndex -KbPath $kb.Path -Id 'install-1a2b3c' -Content $markdown -Title 'Installation'

        Writes index/install-1a2b3c.json.
    #>
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
