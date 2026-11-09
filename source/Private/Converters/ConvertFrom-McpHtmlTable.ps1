function ConvertFrom-McpHtmlTable {
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
