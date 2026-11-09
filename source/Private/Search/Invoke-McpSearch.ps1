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
