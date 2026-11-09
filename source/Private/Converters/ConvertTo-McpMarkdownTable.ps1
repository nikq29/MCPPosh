function ConvertTo-McpMarkdownTable {
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
        $null = $builder.Append('| ').Append(($cells -join ' | ')).AppendLine(' |')
        if ($r -eq 0) {
            $null = $builder.Append('|').Append((@(1..$columnCount | ForEach-Object { ' --- ' }) -join '|')).AppendLine('|')
        }
    }
    $builder.ToString()
}
