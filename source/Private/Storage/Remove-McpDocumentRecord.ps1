function Remove-McpDocumentRecord {
    <#
    .SYNOPSIS
        Removes a document from the manifest and deletes its files.

    .DESCRIPTION
        Removes a document record from manifest.json while holding the knowledge base lock and deletes its content and index files. Throws an error when the document does not exist.

    .PARAMETER KnowledgeBase
        The resolved knowledge base (see Resolve-McpKnowledgeBase) that contains the document.

    .PARAMETER Id
        Id of the document to remove, for example install-1a2b3c.

    .EXAMPLE
        Remove-McpDocumentRecord -KnowledgeBase $kb -Id 'install-1a2b3c'

        Removes the document from the knowledge base.
    #>
    [CmdletBinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal helper; the public cmdlets Remove-McpDocument and Update-McpDocument implement ShouldProcess.')]
    param(
        [Parameter(Mandatory)]
        [object] $KnowledgeBase,

        [Parameter(Mandatory)]
        [string] $Id
    )

    $kbPath = $KnowledgeBase.Path
    $kbLock = Lock-McpKnowledgeBase -KbPath $kbPath
    try {
        $manifest = Read-McpManifest -KbPath $kbPath
        $remaining = @($manifest['documents'] | Where-Object { $_.id -ne $Id })
        if ($remaining.Count -eq @($manifest['documents']).Count) {
            throw "Document '$Id' was not found in knowledge base '$($KnowledgeBase.Name)'."
        }
        $manifest['documents'] = $remaining
        Save-McpManifest -KbPath $kbPath -Manifest $manifest
        $paths = Get-McpDocumentPath -KbPath $kbPath -Id $Id
        Remove-Item -LiteralPath $paths.Content, $paths.Index -Force -ErrorAction SilentlyContinue
    }
    finally {
        $kbLock.Dispose()
    }
}
