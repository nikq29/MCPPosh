function Split-McpTextBySize {
    <#
    .SYNOPSIS
        Splits a long text into chunks of limited size.

    .DESCRIPTION
        Splits text into chunks of at most the given number of characters, preferring paragraph boundaries, then line boundaries, and hard-wrapping only single lines that are longer than the limit.

    .PARAMETER Text
        The text of a section that is longer than the chunk size.

    .PARAMETER MaxChars
        Maximum number of characters per returned chunk.

    .EXAMPLE
        Split-McpTextBySize -Text $longSection -MaxChars 1500

        Returns an array of strings with at most 1500 characters each.
    #>
    [CmdletBinding()]
    [OutputType([string[]], [System.Array])]
    param(
        [Parameter(Mandatory)]
        [string] $Text,

        [int] $MaxChars = 1500
    )

    # Paragraphs first; paragraphs that are still too long are split by lines, then hard-wrapped.
    $units = [System.Collections.Generic.List[string]]::new()
    foreach ($paragraph in [regex]::Split($Text, '\n\s*\n')) {
        if ($paragraph.Length -le $MaxChars) {
            $units.Add($paragraph)
            continue
        }
        $lineBuffer = [System.Text.StringBuilder]::new()
        foreach ($line in ($paragraph -split "`n")) {
            if ($line.Length -gt $MaxChars) {
                if ($lineBuffer.Length -gt 0) { $units.Add($lineBuffer.ToString()); $null = $lineBuffer.Clear() }
                for ($offset = 0; $offset -lt $line.Length; $offset += $MaxChars) {
                    $units.Add($line.Substring($offset, [Math]::Min($MaxChars, $line.Length - $offset)))
                }
                continue
            }
            if ($lineBuffer.Length + $line.Length + 1 -gt $MaxChars -and $lineBuffer.Length -gt 0) {
                $units.Add($lineBuffer.ToString())
                $null = $lineBuffer.Clear()
            }
            if ($lineBuffer.Length -gt 0) { $null = $lineBuffer.Append("`n") }
            $null = $lineBuffer.Append($line)
        }
        if ($lineBuffer.Length -gt 0) { $units.Add($lineBuffer.ToString()) }
    }

    $chunks = [System.Collections.Generic.List[string]]::new()
    $current = [System.Text.StringBuilder]::new()
    foreach ($unit in $units) {
        $trimmed = $unit.Trim()
        if (-not $trimmed) { continue }
        if ($current.Length -gt 0 -and $current.Length + $trimmed.Length + 2 -gt $MaxChars) {
            $chunks.Add($current.ToString())
            $null = $current.Clear()
        }
        if ($current.Length -gt 0) { $null = $current.Append("`n`n") }
        $null = $current.Append($trimmed)
    }
    if ($current.Length -gt 0) { $chunks.Add($current.ToString()) }
    , $chunks.ToArray()
}
