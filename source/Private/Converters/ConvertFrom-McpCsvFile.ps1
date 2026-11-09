function ConvertFrom-McpCsvFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    $delimiter = ','
    if ($extension -eq '.tsv') {
        $delimiter = "`t"
    }
    else {
        $firstLine = (Get-Content -LiteralPath $Path -TotalCount 1 -Encoding utf8)
        if ($firstLine) {
            $counts = @{
                ',' = ([regex]::Matches($firstLine, ',')).Count
                ';' = ([regex]::Matches($firstLine, ';')).Count
                "`t" = ([regex]::Matches($firstLine, "`t")).Count
            }
            $delimiter = ($counts.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 1).Key
        }
    }

    $records = @(Import-Csv -LiteralPath $Path -Delimiter $delimiter -Encoding utf8)
    $fileName = [System.IO.Path]::GetFileName($Path)
    if ($records.Count -eq 0) {
        return @{ Content = "# $fileName`n`n(empty table)`n"; Title = $fileName }
    }
    $headers = [string[]]@($records[0].PSObject.Properties.Name)
    $rows = [System.Collections.Generic.List[string[]]]::new()
    $rows.Add($headers)
    foreach ($record in $records) {
        $rows.Add([string[]]@(foreach ($header in $headers) { [string]$record.$header }))
    }
    $table = ConvertTo-McpMarkdownTable -Rows $rows.ToArray()
    @{
        Content = "# $fileName`n`n$table"
        Title   = $fileName
    }
}
