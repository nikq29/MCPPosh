function Get-McpDocumentPath {
    <#
    .SYNOPSIS
        Returns the content and index file paths of a document.

    .DESCRIPTION
        Returns an object with the Content path (documents/<id>.md) and the Index path (index/<id>.json) of a document in a knowledge base. The files do not need to exist.

    .PARAMETER KbPath
        Directory of the knowledge base that contains the document.

    .PARAMETER Id
        Id of the document, used as the file name of the content and index files.

    .EXAMPLE
        (Get-McpDocumentPath -KbPath $kb.Path -Id 'install-1a2b3c').Content

        Returns the path of documents/install-1a2b3c.md.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $KbPath,

        [Parameter(Mandatory)]
        [string] $Id
    )

    [pscustomobject]@{
        Content = [System.IO.Path]::Combine($KbPath, 'documents', "$Id.md")
        Index   = [System.IO.Path]::Combine($KbPath, 'index', "$Id.json")
    }
}
