function Get-McpSnippet {
    <#
    .SYNOPSIS
        Returns a short excerpt around the first query match.

    .DESCRIPTION
        Collapses whitespace in a text and returns an excerpt of about 240 characters that starts shortly before the first occurrence of a query word, with ellipses where text was cut.

    .PARAMETER Text
        The text of the search result chunk to take the excerpt from.

    .PARAMETER Query
        The search query; the excerpt is placed around the first of its words found in the text.

    .PARAMETER Length
        Maximum length of the excerpt in characters, without the ellipses.

    .EXAMPLE
        Get-McpSnippet -Text $chunk.text -Query 'restart vpn service'

        Returns the part of the chunk that mentions the VPN restart.
    #>
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
    if ($start -gt 0) { $snippet = [string][char]0x2026 + $snippet }
    if ($end -lt $flat.Length) { $snippet = $snippet + [char]0x2026 }
    $snippet
}
