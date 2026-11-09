function Get-McpHtmlInnerText {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()]
        [string] $Html
    )

    $text = [regex]::Replace($Html, '<[^>]+>', ' ')
    $text = [System.Net.WebUtility]::HtmlDecode($text)
    [regex]::Replace($text, '\s+', ' ').Trim()
}
