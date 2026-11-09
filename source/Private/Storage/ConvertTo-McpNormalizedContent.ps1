function ConvertTo-McpNormalizedContent {
    <#
    .SYNOPSIS
        Normalizes document text before it is stored.

    .DESCRIPTION
        Converts line endings to LF, removes a leading byte order mark and trailing whitespace on each line, trims empty lines at the start and the end and terminates the text with a single newline, so identical content always produces the same hash.

    .PARAMETER Content
        The Markdown or text content to normalize. An empty string results in a single newline.

    .EXAMPLE
        ConvertTo-McpNormalizedContent -Content "
        # Title
        Text

        "

        Returns "# Title`nText`n".
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()]
        [string] $Content
    )

    $text = ([string]$Content).Replace("`r`n", "`n").Replace("`r", "`n")
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) {
        $text = $text.Substring(1)
    }
    $text = [regex]::Replace($text, '[ \t]+(?=\n)', '')
    $text.Trim("`n") + "`n"
}
