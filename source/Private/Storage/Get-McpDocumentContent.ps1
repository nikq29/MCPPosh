function Get-McpDocumentContent {
    <#
    .SYNOPSIS
        Reads the Markdown content of a document.

    .DESCRIPTION
        Returns the normalized Markdown content of a document from the documents folder of a knowledge base, or $null when the content file does not exist or the id is not a valid document id.

    .PARAMETER KbPath
        Directory of the knowledge base that contains the document.

    .PARAMETER Id
        Id of the document whose content is returned, for example install-1a2b3c.

    .EXAMPLE
        Get-McpDocumentContent -KbPath $kb.Path -Id 'install-1a2b3c'

        Returns the Markdown text of the document.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $KbPath,

        [Parameter(Mandatory)]
        [string] $Id
    )

    if (-not (Test-McpDocumentId -Id $Id)) {
        return $null
    }
    $paths = Get-McpDocumentPath -KbPath $KbPath -Id $Id
    if (-not (Test-Path -LiteralPath $paths.Content -PathType Leaf)) {
        return $null
    }
    Read-McpTextFile -Path $paths.Content
}
