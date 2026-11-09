function ConvertTo-McpMarkdownTableCell {
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
