function Set-McpDocumentProperty {
    <#
    .SYNOPSIS
        Changes the title or tags of a stored document.

    .DESCRIPTION
        Updates the title and/or the tags of a document record in the manifest while holding the knowledge base lock. When the title changes, the search index of the document is rebuilt because titles are indexed.

    .PARAMETER KnowledgeBase
        The resolved knowledge base (see Resolve-McpKnowledgeBase) that contains the document.

    .PARAMETER Id
        Id of the document to change, for example install-1a2b3c.

    .PARAMETER Title
        New title of the document. Empty values leave the title unchanged.

    .PARAMETER Tags
        New tags of the document; they replace the existing tags. An empty array removes all tags.

    .EXAMPLE
        Set-McpDocumentProperty -KnowledgeBase $kb -Id 'install-1a2b3c' -Tags setup, windows

        Replaces the tags of the document and returns the updated record.
    #>
    [CmdletBinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal helper; the public cmdlet Set-McpDocument implements ShouldProcess.')]
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
    $kbLock = Lock-McpKnowledgeBase -KbPath $kbPath
    try {
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
    finally {
        $kbLock.Dispose()
    }
}
