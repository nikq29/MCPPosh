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
