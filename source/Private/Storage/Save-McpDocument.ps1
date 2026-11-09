function Save-McpDocument {
    <#
    .SYNOPSIS
        Inserts or updates a document (content, search index and manifest record).
    .OUTPUTS
        A hashtable with Record, Created and Changed.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $KnowledgeBase,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Content,

        [Parameter(Mandatory)]
        [string] $Title,

        [string] $Format = 'Markdown',

        [ValidateSet('File', 'Url', 'Inline', 'Agent')]
        [string] $SourceType = 'Inline',

        [string] $Source,

        [string[]] $Tags = @(),

        [string] $SourceHash,

        [string] $Id,

        # Keep the tags of an existing document in addition to -Tags (used when re-importing
        # a file or URL without explicitly specifying tags).
        [switch] $MergeExistingTags
    )

    $kbPath = $KnowledgeBase.Path
    $normalized = ConvertTo-McpNormalizedContent -Content $Content
    $hash = Get-McpSha256 -Text $normalized
    $cleanTags = @($Tags | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() } | Sort-Object -Unique)

    Invoke-McpKnowledgeBaseLock -KbPath $kbPath -ScriptBlock {
        $manifest = Read-McpManifest -KbPath $kbPath
        $documents = [System.Collections.Generic.List[object]]::new()
        foreach ($doc in $manifest['documents']) { $documents.Add($doc) }

        $existing = Find-McpDocumentRecord -Documents $documents.ToArray() -Id $Id -SourceType $SourceType -Source $Source -Title $Title
        if ($Id -and -not $existing) {
            throw "Document '$Id' was not found in knowledge base '$($KnowledgeBase.Name)'."
        }

        $now = Get-McpUtcNow
        if ($existing -and $MergeExistingTags) {
            $cleanTags = @(@($cleanTags) + @($existing.tags) | Where-Object { $_ } | Sort-Object -Unique)
        }
        if ($existing) {
            $unchanged = $existing.hash -eq $hash -and $existing.title -eq $Title -and $existing.format -eq $Format -and
                ((@($existing.tags) -join "`n") -eq ($cleanTags -join "`n")) -and ([string]$existing.source) -eq $Source -and $existing.sourceType -eq $SourceType
            if ($unchanged) {
                if ($SourceHash -and $existing.sourceHash -ne $SourceHash) {
                    $existing['sourceHash'] = $SourceHash
                    Save-McpManifest -KbPath $kbPath -Manifest $manifest
                }
                return @{ Record = $existing; Created = $false; Changed = $false }
            }
            $record = $existing
            $docId = [string]$record.id
        }
        else {
            $docId = New-McpDocumentId -Title $Title -ExistingIds @($documents | ForEach-Object { $_.id })
            $record = [ordered]@{ id = $docId }
            $documents.Add($record)
        }

        $record['title'] = $Title
        $record['format'] = $Format
        $record['sourceType'] = $SourceType
        $record['source'] = if ($Source) { $Source } else { $null }
        $record['tags'] = $cleanTags
        $record['hash'] = $hash
        $record['sourceHash'] = if ($SourceHash) { $SourceHash } else { $null }
        $record['chars'] = $normalized.Length
        $record['summary'] = Get-McpContentSummary -Content $normalized
        if (-not $record.Contains('added') -or -not $record['added']) { $record['added'] = $now }
        $record['updated'] = $now

        # Content and index first, manifest last: a server reloading on manifest change always
        # finds the files the manifest points to.
        $paths = Get-McpDocumentPath -KbPath $kbPath -Id $docId
        Write-McpTextFile -Path $paths.Content -Content $normalized
        Write-McpDocumentIndex -KbPath $kbPath -Id $docId -Content $normalized -Title $Title

        $manifest['documents'] = $documents.ToArray()
        Save-McpManifest -KbPath $kbPath -Manifest $manifest
        @{ Record = $record; Created = (-not $existing); Changed = $true }
    }
}
