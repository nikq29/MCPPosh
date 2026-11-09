function Get-McpContentSummary {
    <#
    .SYNOPSIS
        Creates a short plain-text summary of a document.

    .DESCRIPTION
        Takes the first paragraph of a Markdown document that is not a heading, table separator or code block, removes Markdown formatting and links and shortens it to the maximum length. The summary is shown by list_documents.

    .PARAMETER Content
        The normalized Markdown content of the document to summarize.

    .PARAMETER MaxLength
        Maximum number of characters of the summary. Longer summaries end with an ellipsis.

    .EXAMPLE
        Get-McpContentSummary -Content "# Backup

        The nightly **backup** runs at 02:00."

        Returns: The nightly backup runs at 02:00.
    #>
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
        $summary = $summary.Substring(0, $MaxLength).TrimEnd() + [char]0x2026
    }
    $summary
}
