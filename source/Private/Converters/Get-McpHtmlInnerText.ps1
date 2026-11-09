function Get-McpHtmlInnerText {
    <#
    .SYNOPSIS
        Returns the plain text of an HTML fragment.

    .DESCRIPTION
        Removes all tags from an HTML fragment, decodes HTML entities and collapses whitespace to single spaces.

    .PARAMETER Html
        The HTML fragment whose text content is returned.

    .EXAMPLE
        Get-McpHtmlInnerText -Html '<b>Fish &amp; Chips</b>'

        Returns: Fish & Chips
    #>
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
