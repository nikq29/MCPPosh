function Get-McpDocumentPath {
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
