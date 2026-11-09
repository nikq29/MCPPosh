function ConvertTo-McpMarkdownTableCell {
    <#
    .SYNOPSIS
        Formats a value for a Markdown table cell.

    .DESCRIPTION
        Converts a value to a single-line string for a Markdown table cell: line breaks are replaced with spaces and pipe characters are escaped.

    .PARAMETER Value
        The cell value to format. $null results in an empty cell.

    .EXAMPLE
        ConvertTo-McpMarkdownTableCell -Value "Servicedesk | 24/7
        Phone"

        Returns: Servicedesk \| 24/7 Phone
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object] $Value
    )

    $text = [string]$Value
    $text = [regex]::Replace($text, '\s*\r?\n\s*', ' ')
    $text.Replace('|', '\|').Trim()
}
