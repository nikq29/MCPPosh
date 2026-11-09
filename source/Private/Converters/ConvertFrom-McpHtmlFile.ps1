function ConvertFrom-McpHtmlFile {
    <#
    .SYNOPSIS
        Converts a local HTML file to Markdown.

    .DESCRIPTION
        Reads a local .html or .htm file and converts it to Markdown with ConvertFrom-McpHtml, including the page title.

    .PARAMETER Path
        Path of the HTML file to convert.

    .EXAMPLE
        ConvertFrom-McpHtmlFile -Path ./wiki/vpn.html

        Returns a hashtable with the Markdown Content and the Title from the <title> element.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    ConvertFrom-McpHtml -Html (Read-McpTextFile -Path $Path)
}
