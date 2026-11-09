function ConvertTo-McpNormalizedContent {
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
