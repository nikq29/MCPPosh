function ConvertTo-McpMarkdownTable {
    <#
    .SYNOPSIS
        Creates a Markdown table from rows of cells.

    .DESCRIPTION
        Creates a Markdown table from an array of rows, each an array of cell values. The first row becomes the header; shorter rows are padded and pipe characters in cells are escaped.

    .PARAMETER Rows
        The table rows as an array of string arrays; the first row contains the column headers.

    .EXAMPLE
        ConvertTo-McpMarkdownTable -Rows @(,[string[]]@('Name', 'Role'), [string[]]@('Anna', 'Admin'))

        Returns a two-column Markdown table with one data row.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[][]] $Rows
    )

    if ($Rows.Count -eq 0) { return '' }
    $columnCount = ($Rows | ForEach-Object { $_.Count } | Measure-Object -Maximum).Maximum
    if (-not $columnCount) { return '' }

    $builder = [System.Text.StringBuilder]::new()
    for ($r = 0; $r -lt $Rows.Count; $r++) {
        $cells = for ($c = 0; $c -lt $columnCount; $c++) {
            if ($c -lt $Rows[$r].Count) { ConvertTo-McpMarkdownTableCell -Value $Rows[$r][$c] } else { '' }
        }
        $null = $builder.Append('| ').Append(($cells -join ' | ')).Append(" |`n")
        if ($r -eq 0) {
            $null = $builder.Append('|').Append((@(1..$columnCount | ForEach-Object { ' --- ' }) -join '|')).Append("|`n")
        }
    }
    $builder.ToString()
}
