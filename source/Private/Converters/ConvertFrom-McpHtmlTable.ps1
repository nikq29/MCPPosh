function ConvertFrom-McpHtmlTable {
    <#
    .SYNOPSIS
        Converts an HTML table to a Markdown table.

    .DESCRIPTION
        Extracts the rows and header or data cells of an HTML table element and converts them to a Markdown table; the first row becomes the header row.

    .PARAMETER TableHtml
        The HTML markup of a single table element including its rows and cells.

    .EXAMPLE
        ConvertFrom-McpHtmlTable -TableHtml '<table><tr><th>Code</th></tr><tr><td>809</td></tr></table>'

        Returns a Markdown table with the header Code and the row 809.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()]
        [string] $TableHtml
    )

    $rows = [System.Collections.Generic.List[string[]]]::new()
    foreach ($rowMatch in [regex]::Matches($TableHtml, '(?is)<tr\b[^>]*>(.*?)</tr>')) {
        $cells = [System.Collections.Generic.List[string]]::new()
        foreach ($cellMatch in [regex]::Matches($rowMatch.Groups[1].Value, '(?is)<t[hd]\b[^>]*>(.*?)</t[hd]>')) {
            $cells.Add((Get-McpHtmlInnerText -Html $cellMatch.Groups[1].Value))
        }
        if ($cells.Count -gt 0) { $rows.Add($cells.ToArray()) }
    }
    if ($rows.Count -eq 0) { return '' }
    "`n`n" + (ConvertTo-McpMarkdownTable -Rows $rows.ToArray()) + "`n`n"
}
