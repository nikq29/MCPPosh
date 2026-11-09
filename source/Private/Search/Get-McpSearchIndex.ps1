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
        $paths = Get-McpDocumentPath -KbPath $KbPath -Id $docId
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
