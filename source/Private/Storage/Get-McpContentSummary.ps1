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
