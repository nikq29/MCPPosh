function Read-McpManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $KbPath
    )

    $manifest = Read-McpJsonFile -Path (Join-Path -Path $KbPath -ChildPath 'manifest.json')
    if ($null -eq $manifest) {
        $manifest = [ordered]@{ schemaVersion = 1; revision = 0; updated = $null; documents = @() }
    }
    if ($null -eq $manifest['documents']) {
        $manifest['documents'] = @()
    }
    $manifest
}

function Save-McpManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $KbPath,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Manifest
    )

    $Manifest['revision'] = [long]$Manifest['revision'] + 1
    $Manifest['updated'] = Get-McpUtcNow
    Write-McpJsonFile -Path (Join-Path -Path $KbPath -ChildPath 'manifest.json') -InputObject $Manifest
}

function ConvertTo-McpSlug {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()]
        [string] $Text
    )

    $slug = ([string]$Text).ToLowerInvariant().Replace('ä', 'ae').Replace('ö', 'oe').Replace('ü', 'ue').Replace('ß', 'ss')
    $slug = [regex]::Replace($slug.Normalize([System.Text.NormalizationForm]::FormD), '\p{Mn}+', '')
    $slug = [regex]::Replace($slug, '[^a-z0-9]+', '-').Trim('-')
    if ($slug.Length -gt 48) {
        $slug = $slug.Substring(0, 48).Trim('-')
    }
    if (-not $slug) {
        $slug = 'document'
    }
    $slug
}

function New-McpDocumentId {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()]
        [string] $Title,

        [string[]] $ExistingIds = @()
    )

    $slug = ConvertTo-McpSlug -Text $Title
    do {
        $id = '{0}-{1}' -f $slug, [guid]::NewGuid().ToString('N').Substring(0, 6)
    } while ($ExistingIds -contains $id)
    $id
}

function ConvertTo-McpNormalizedContent {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()]
        [string] $Content
    )

    $text = ([string]$Content).Replace("`r`n", "`n").Replace("`r", "`n")
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) {
        $text = $text.Substring(1)
    }
    $text = [regex]::Replace($text, '[ \t]+(?=\n)', '')
    $text.Trim("`n") + "`n"
}

function Get-McpContentSummary {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()]
        [string] $Content,

        [int] $MaxLength = 200
    )

    $inFence = $false
    $parts = [System.Collections.Generic.List[string]]::new()
    foreach ($line in ($Content -split "`n")) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^(```|~~~)') { $inFence = -not $inFence; continue }
        if ($inFence -or -not $trimmed -or $trimmed -match '^#{1,6}\s' -or $trimmed -match '^[-|: ]+$') {
            if ($parts.Count -gt 0 -and -not $trimmed) { break }
            continue
        }
        $parts.Add($trimmed)
        if (($parts -join ' ').Length -ge $MaxLength) { break }
    }
    $summary = ($parts -join ' ')
    $summary = [regex]::Replace($summary, '!?\[([^\]]*)\]\([^)]*\)', '$1')
    $summary = [regex]::Replace($summary, '[*_`>|]+', '')
    $summary = [regex]::Replace($summary, '\s+', ' ').Trim()
    if ($summary.Length -gt $MaxLength) {
        $summary = $summary.Substring(0, $MaxLength).TrimEnd() + '…'
    }
    $summary
}

function Get-McpDocumentPaths {
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

    $paths = Get-McpDocumentPaths -KbPath $KbPath -Id $Id
    $chunks = New-McpChunkIndex -Content $Content -Title $Title
    Write-McpJsonFile -Path $paths.Index -InputObject ([ordered]@{
            schemaVersion = 1
            id            = $Id
            chunks        = $chunks
        })
}

function Find-McpDocumentRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Documents,

        [string] $Id,

        [string] $SourceType,

        [string] $Source,

        [string] $Title
    )

    foreach ($doc in $Documents) {
        if ($Id) {
            if ($doc.id -eq $Id) { return $doc }
            continue
        }
        if ($SourceType -in 'File', 'Url' -and $Source) {
            if ($doc.sourceType -eq $SourceType -and $doc.source -eq $Source) { return $doc }
            continue
        }
        if ($SourceType -eq 'Inline' -and $Title) {
            if ($doc.sourceType -eq 'Inline' -and $doc.title -eq $Title) { return $doc }
        }
    }
    $null
}

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
        $paths = Get-McpDocumentPaths -KbPath $kbPath -Id $docId
        Write-McpTextFile -Path $paths.Content -Content $normalized
        Write-McpDocumentIndex -KbPath $kbPath -Id $docId -Content $normalized -Title $Title

        $manifest['documents'] = $documents.ToArray()
        Save-McpManifest -KbPath $kbPath -Manifest $manifest
        @{ Record = $record; Created = (-not $existing); Changed = $true }
    }
}

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
            $paths = Get-McpDocumentPaths -KbPath $kbPath -Id $Id
            if (Test-Path -LiteralPath $paths.Content) {
                Write-McpDocumentIndex -KbPath $kbPath -Id $Id -Content (Read-McpTextFile -Path $paths.Content) -Title $record['title']
            }
        }
        Save-McpManifest -KbPath $kbPath -Manifest $manifest
        $record
    }
}

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
        $paths = Get-McpDocumentPaths -KbPath $kbPath -Id $Id
        Remove-Item -LiteralPath $paths.Content, $paths.Index -Force -ErrorAction SilentlyContinue
    }
}

function Get-McpDocumentContent {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $KbPath,

        [Parameter(Mandatory)]
        [string] $Id
    )

    $paths = Get-McpDocumentPaths -KbPath $KbPath -Id $Id
    if (-not (Test-Path -LiteralPath $paths.Content -PathType Leaf)) {
        return $null
    }
    Read-McpTextFile -Path $paths.Content
}

function ConvertTo-McpDocumentObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Record,

        [Parameter(Mandatory)]
        [object] $KnowledgeBase,

        [switch] $IncludeContent
    )

    $object = [ordered]@{
        PSTypeName    = 'MCPPosh.Document'
        Id            = [string]$Record.id
        Title         = [string]$Record.title
        Format        = [string]$Record.format
        Tags          = [string[]]@($Record.tags | Where-Object { $_ })
        SourceType    = [string]$Record.sourceType
        Source        = $Record.source
        Summary       = [string]$Record.summary
        Chars         = [int]$Record.chars
        Added         = ConvertTo-McpDateTime -Value $Record.added
        Updated       = ConvertTo-McpDateTime -Value $Record.updated
        KnowledgeBase = $KnowledgeBase.Name
        Uri           = 'mcpposh://{0}/documents/{1}' -f $KnowledgeBase.Name, $Record.id
    }
    if ($IncludeContent) {
        $object['Content'] = Get-McpDocumentContent -KbPath $KnowledgeBase.Path -Id $Record.id
    }
    [pscustomobject]$object
}
