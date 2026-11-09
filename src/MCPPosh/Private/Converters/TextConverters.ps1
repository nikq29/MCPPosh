function Split-McpFrontMatter {
    <#
    .SYNOPSIS
        Separates YAML front matter from Markdown and extracts 'title' and 'tags'.
    #>
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string] $Text
    )

    $result = @{ Body = $Text; Title = $null; Tags = @() }
    $match = [regex]::Match($Text, '\A﻿?---[ \t]*\r?\n(?<fm>[\s\S]*?)\r?\n(---|\.\.\.)[ \t]*(\r?\n|\z)')
    if (-not $match.Success) {
        return $result
    }

    $result.Body = $Text.Substring($match.Length)
    $tags = [System.Collections.Generic.List[string]]::new()
    $inTags = $false
    foreach ($line in ($match.Groups['fm'].Value -split '\r?\n')) {
        if ($line -match '^title\s*:\s*(.+)$') {
            $result.Title = $Matches[1].Trim().Trim('"', "'")
            $inTags = $false
            continue
        }
        if ($line -match '^(tags|keywords)\s*:\s*(.*)$') {
            $value = $Matches[2].Trim()
            $inTags = -not $value
            if ($value) {
                foreach ($tag in ($value.Trim('[', ']') -split ',')) {
                    $clean = $tag.Trim().Trim('"', "'")
                    if ($clean) { $tags.Add($clean) }
                }
            }
            continue
        }
        if ($inTags -and $line -match '^\s*-\s*(.+)$') {
            $tags.Add($Matches[1].Trim().Trim('"', "'"))
            continue
        }
        $inTags = $false
    }
    $result.Tags = $tags.ToArray()
    $result
}

function Get-McpMarkdownTitle {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()]
        [string] $Markdown
    )

    $match = [regex]::Match($Markdown, '(?m)^\s{0,3}#\s+(.+?)\s*#*\s*$')
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    $null
}

function ConvertFrom-McpMarkdownFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $text = Read-McpTextFile -Path $Path
    $frontMatter = Split-McpFrontMatter -Text $text
    $title = if ($frontMatter.Title) { $frontMatter.Title } else { Get-McpMarkdownTitle -Markdown $frontMatter.Body }
    @{
        Content = $frontMatter.Body
        Title   = $title
        Tags    = $frontMatter.Tags
    }
}

function ConvertFrom-McpTextFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    @{ Content = Read-McpTextFile -Path $Path }
}

function Get-McpCodeFence {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()]
        [string] $Text
    )

    $longest = 2
    foreach ($match in [regex]::Matches($Text, '`{3,}')) {
        if ($match.Length -gt $longest) { $longest = $match.Length }
    }
    '`' * ($longest + 1)
}

function ConvertFrom-McpCodeFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [string] $Language,

        [string] $Format = 'Code'
    )

    if (-not $Language) {
        $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
        $fileName = [System.IO.Path]::GetFileName($Path).ToLowerInvariant()
        $Language = if ($script:McpCodeLanguages.ContainsKey($extension)) { $script:McpCodeLanguages[$extension] }
        elseif ($script:McpCodeFileNames.ContainsKey($fileName)) { $script:McpCodeFileNames[$fileName] }
        else { '' }
    }

    $code = (Read-McpTextFile -Path $Path).TrimEnd()
    $fence = Get-McpCodeFence -Text $code
    $fileName = [System.IO.Path]::GetFileName($Path)
    @{
        Content = "# $fileName`n`n$fence$Language`n$code`n$fence`n"
        Title   = $fileName
        Format  = $Format
    }
}

function ConvertTo-McpMarkdownTableCell {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object] $Value
    )

    $text = [string]$Value
    $text = [regex]::Replace($text, '\s*\r?\n\s*', ' ')
    $text.Replace('|', '\|').Trim()
}

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

function ConvertFrom-McpPdfFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $text = Invoke-McpPdfTextExtraction -Path $Path
    $text = ([string]$text).Replace("`f", "`n`n")
    @{ Content = $text }
}

function Invoke-McpPdfTextExtraction {
    <#
    .SYNOPSIS
        Extracts text from a PDF using PSWritePDF (preferred) or pdftotext (Poppler).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    if (Get-Module -ListAvailable -Name PSWritePDF) {
        Import-Module -Name PSWritePDF -ErrorAction Stop -Verbose:$false
        $pages = Convert-PDFToText -FilePath $Path
        return (@($pages) | ForEach-Object { [string]$_ }) -join "`n`n"
    }

    $pdftotext = Get-Command -Name 'pdftotext' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pdftotext) {
        $output = & $pdftotext.Source -layout -enc UTF-8 $Path - 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "pdftotext failed with exit code $LASTEXITCODE for '$Path'."
        }
        return (@($output) -join "`n")
    }

    throw ("PDF support requires the PowerShell module 'PSWritePDF' (Install-Module PSWritePDF -Scope CurrentUser) " +
        "or the 'pdftotext' tool from Poppler (Windows: winget install oschwartz10612.Poppler, macOS: brew install poppler, Linux: apt install poppler-utils).")
}
