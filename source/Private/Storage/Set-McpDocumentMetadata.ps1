function Set-McpDocumentMetadata {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $KnowledgeBase,

        [Parameter(Mandatory)]
        [string] $Id,

        [string] $Title,

        [AllowEmptyCollection()]
        [string[]] $Tags
    )

    $kbPath = $KnowledgeBase.Path
    $setTitle = $PSBoundParameters.ContainsKey('Title') -and -not [string]::IsNullOrWhiteSpace($Title)
    $setTags = $PSBoundParameters.ContainsKey('Tags')
    Invoke-McpKnowledgeBaseLock -KbPath $kbPath -ScriptBlock {
        $manifest = Read-McpManifest -KbPath $kbPath
        $record = Find-McpDocumentRecord -Documents @($manifest['documents']) -Id $Id
        if (-not $record) {
            throw "Document '$Id' was not found in knowledge base '$($KnowledgeBase.Name)'."
        }
        if ($setTitle) { $record['title'] = $Title }
        if ($setTags) {
            $record['tags'] = @($Tags | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() } | Sort-Object -Unique)
        }
        $record['updated'] = Get-McpUtcNow
        if ($setTitle) {
            $paths = Get-McpDocumentPath -KbPath $kbPath -Id $Id
            if (Test-Path -LiteralPath $paths.Content) {
                Write-McpDocumentIndex -KbPath $kbPath -Id $Id -Content (Read-McpTextFile -Path $paths.Content) -Title $record['title']
            }
        }
        Save-McpManifest -KbPath $kbPath -Manifest $manifest
        $record
    }
}
