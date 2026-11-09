$script:McpIndexCache = @{}

function Get-McpManifestStamp {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $KbPath
    )

    $file = [System.IO.FileInfo]::new([System.IO.Path]::Combine($KbPath, 'manifest.json'))
    $file.Refresh()
    if (-not $file.Exists) { return '0' }
    '{0}-{1}' -f $file.LastWriteTimeUtc.Ticks, $file.Length
}

function Get-McpSearchIndex {
    <#
    .SYNOPSIS
        Loads (and caches) the in-memory search index of a knowledge base.
    .DESCRIPTION
        The cache is keyed by the manifest's timestamp and size, so documents added from another
        PowerShell session become searchable without restarting a running server.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $KbPath,

        [switch] $Force
    )

    $stamp = Get-McpManifestStamp -KbPath $KbPath
    $cached = $script:McpIndexCache[$KbPath]
    if (-not $Force -and $null -ne $cached -and $cached.Stamp -eq $stamp) {
        return $cached
    }

    $manifest = Read-McpManifest -KbPath $KbPath
    $docs = @{}
    $chunks = [System.Collections.Generic.List[object]]::new()
    $postings = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[int[]]]]::new([System.StringComparer]::Ordinal)
    $totalLength = 0L

    foreach ($doc in $manifest['documents']) {
        $docId = [string]$doc.id
        $docs[$docId] = $doc
        $paths = Get-McpDocumentPaths -KbPath $KbPath -Id $docId
        $index = $null
        if (Test-Path -LiteralPath $paths.Index -PathType Leaf) {
            try {
                $index = (Read-McpTextFile -Path $paths.Index) | ConvertFrom-Json -AsHashtable -Depth 64
            }
            catch {
                $index = $null
            }
        }
        if ($null -eq $index -and (Test-Path -LiteralPath $paths.Content -PathType Leaf)) {
            # Index missing or corrupt (e.g. partially copied share): rebuild it from the content.
            Write-McpDocumentIndex -KbPath $KbPath -Id $docId -Content (Read-McpTextFile -Path $paths.Content) -Title ([string]$doc.title)
            $index = (Read-McpTextFile -Path $paths.Index) | ConvertFrom-Json -AsHashtable -Depth 64
        }
        if ($null -eq $index) { continue }

        foreach ($chunk in @($index['chunks'])) {
            if ($null -eq $chunk) { continue }
            $chunkIndex = $chunks.Count
            $length = [int]$chunk['len']
            $chunks.Add(@{
                    docId   = $docId
                    heading = [string]$chunk['heading']
                    text    = [string]$chunk['text']
                    len     = $length
                })
            $totalLength += $length
            $tf = $chunk['tf']
            if ($null -eq $tf) { continue }
            foreach ($entry in $tf.GetEnumerator()) {
                $list = $null
                if (-not $postings.TryGetValue($entry.Key, [ref] $list)) {
                    $list = [System.Collections.Generic.List[int[]]]::new()
                    $postings[$entry.Key] = $list
                }
                $list.Add([int[]]@($chunkIndex, [int]$entry.Value))
            }
        }
    }

    $result = [pscustomobject]@{
        Stamp     = $stamp
        KbPath    = $KbPath
        Revision  = [long]$manifest['revision']
        Documents = $docs
        Chunks    = $chunks
        Postings  = $postings
        AvgLength = if ($chunks.Count -gt 0) { [double]$totalLength / $chunks.Count } else { 1.0 }
    }
    $script:McpIndexCache[$KbPath] = $result
    $result
}

function Invoke-McpSearch {
    <#
    .SYNOPSIS
        Ranks chunks of a search index against a query using BM25.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Index,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Query,

        [ValidateRange(1, 100)]
        [int] $Top = 5,

        [string[]] $Tags,

        [int] $MaxPerDocument = 3
    )

    $allTokens = Get-McpToken -Text $Query
    $queryTokens = [string[]]@($allTokens | Select-Object -Unique)
    $chunkCount = $Index.Chunks.Count
    if ($queryTokens.Count -eq 0 -or $chunkCount -eq 0) {
        return
    }

    $k1 = 1.2
    $b = 0.75
    $avgLength = [Math]::Max(1.0, [double]$Index.AvgLength)

    # Exact terms; unknown terms are expanded to indexed terms with the same prefix
    # (e.g. "konfig" -> "konfiguration") at a reduced weight.
    $terms = [System.Collections.Generic.List[object]]::new()
    foreach ($token in $queryTokens) {
        if ($Index.Postings.ContainsKey($token)) {
            $terms.Add(@($token, 1.0))
            continue
        }
        if ($token.Length -lt 3) { continue }
        $expanded = 0
        foreach ($key in $Index.Postings.Keys) {
            if ($key.StartsWith($token, [System.StringComparison]::Ordinal)) {
                $terms.Add(@($key, 0.7))
                if (++$expanded -ge 20) { break }
            }
        }
    }
    if ($terms.Count -eq 0) {
        return
    }

    $scores = [System.Collections.Generic.Dictionary[int, double]]::new()
    $matched = [System.Collections.Generic.Dictionary[int, int]]::new()
    foreach ($term in $terms) {
        $postingList = $Index.Postings[$term[0]]
        $weight = [double]$term[1]
        $df = $postingList.Count
        $idf = [Math]::Log(1.0 + ($chunkCount - $df + 0.5) / ($df + 0.5))
        foreach ($posting in $postingList) {
            $chunkIndex = $posting[0]
            $tf = [double]$posting[1]
            $length = [double]$Index.Chunks[$chunkIndex].len
            $score = $weight * $idf * ($tf * ($k1 + 1.0)) / ($tf + $k1 * (1.0 - $b + $b * $length / $avgLength))
            $current = 0.0
            if ($scores.TryGetValue($chunkIndex, [ref] $current)) {
                $scores[$chunkIndex] = $current + $score
                $matched[$chunkIndex] = $matched[$chunkIndex] + 1
            }
            else {
                $scores[$chunkIndex] = $score
                $matched[$chunkIndex] = 1
            }
        }
    }

    $tagFilter = @($Tags | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $termCount = [Math]::Max(1, $queryTokens.Count)
    $ranked = foreach ($entry in $scores.GetEnumerator()) {
        $chunk = $Index.Chunks[$entry.Key]
        $doc = $Index.Documents[$chunk.docId]
        if ($tagFilter.Count -gt 0) {
            $docTags = @($doc.tags)
            $hit = $false
            foreach ($tag in $tagFilter) { if ($docTags -contains $tag) { $hit = $true; break } }
            if (-not $hit) { continue }
        }
        # Small boost for chunks that cover more of the distinct query terms.
        $coverage = [Math]::Min(1.0, $matched[$entry.Key] / $termCount)
        [pscustomobject]@{
            ChunkIndex = $entry.Key
            Score      = $entry.Value * (0.75 + 0.25 * $coverage)
        }
    }

    $perDocument = @{}
    $emitted = 0
    foreach ($item in ($ranked | Sort-Object -Property Score -Descending)) {
        $chunk = $Index.Chunks[$item.ChunkIndex]
        $count = [int]$perDocument[$chunk.docId]
        if ($count -ge $MaxPerDocument) { continue }
        $perDocument[$chunk.docId] = $count + 1
        $doc = $Index.Documents[$chunk.docId]
        [pscustomobject]@{
            PSTypeName = 'MCPPosh.SearchResult'
            Score      = [Math]::Round($item.Score, 3)
            DocumentId = $chunk.docId
            Title      = [string]$doc.title
            Heading    = $chunk.heading
            Tags       = [string[]]@($doc.tags | Where-Object { $_ })
            Source     = $doc.source
            Snippet    = Get-McpSnippet -Text $chunk.text -Query $Query
            Text       = $chunk.text
        }
        if (++$emitted -ge $Top) { break }
    }
}

function Get-McpSnippet {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()]
        [string] $Text,

        [AllowEmptyString()]
        [string] $Query,

        [int] $Length = 240
    )

    $flat = [regex]::Replace($Text, '\s+', ' ').Trim()
    if ($flat.Length -le $Length) { return $flat }

    $lower = $flat.ToLowerInvariant()
    $position = -1
    foreach ($word in ($Query.ToLowerInvariant() -split '[^\p{L}\p{N}]+')) {
        if ($word.Length -lt 3) { continue }
        $stem = if ($word.Length -gt 5) { $word.Substring(0, $word.Length - 2) } else { $word }
        $found = $lower.IndexOf($stem, [System.StringComparison]::Ordinal)
        if ($found -ge 0 -and ($position -lt 0 -or $found -lt $position)) { $position = $found }
    }
    $start = if ($position -lt 0) { 0 } else { [Math]::Max(0, $position - 60) }
    $end = [Math]::Min($flat.Length, $start + $Length)
    $snippet = $flat.Substring($start, $end - $start).Trim()
    if ($start -gt 0) { $snippet = '…' + $snippet }
    if ($end -lt $flat.Length) { $snippet = $snippet + '…' }
    $snippet
}
