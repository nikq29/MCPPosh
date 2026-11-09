function Remove-McpDocumentRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $KnowledgeBase,

        [Parameter(Mandatory)]
        [string] $Id
    )

    $kbPath = $KnowledgeBase.Path
    Invoke-McpKnowledgeBaseLock -KbPath $kbPath -ScriptBlock {
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
}
