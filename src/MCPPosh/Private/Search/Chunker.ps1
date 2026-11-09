function Split-McpMarkdownSection {
    <#
    .SYNOPSIS
        Splits Markdown into sections by heading, then into chunks of at most MaxChars characters.
    .OUTPUTS
        Ordered dictionaries with 'heading' (heading path, e.g. "Setup > Requirements") and 'text'.
    #>
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string] $Content,

        [int] $MaxChars = 1500
    )

    $sections = [System.Collections.Generic.List[object]]::new()
    $headingStack = [string[]]::new(7)
    $currentPath = ''
    $buffer = [System.Text.StringBuilder]::new()
    $fenceChar = $null

    $flush = {
        $text = $buffer.ToString().Trim()
        if ($text) {
            $sections.Add([ordered]@{ heading = $currentPath; text = $text })
        }
        $null = $buffer.Clear()
    }

    foreach ($line in ($Content -split "`n")) {
        $fenceMatch = [regex]::Match($line, '^\s{0,3}(`{3,}|~{3,})')
        if ($fenceMatch.Success) {
            $char = $fenceMatch.Groups[1].Value[0]
            if ($null -eq $fenceChar) { $fenceChar = $char }
            elseif ($fenceChar -eq $char) { $fenceChar = $null }
            $null = $buffer.AppendLine($line)
            continue
        }
        if ($null -eq $fenceChar) {
            $headingMatch = [regex]::Match($line, '^\s{0,3}(#{1,6})\s+(.+?)\s*#*\s*$')
            if ($headingMatch.Success) {
                . $flush
                $level = $headingMatch.Groups[1].Value.Length
                $headingStack[$level] = $headingMatch.Groups[2].Value.Trim()
                for ($i = $level + 1; $i -le 6; $i++) { $headingStack[$i] = $null }
                $currentPath = (@($headingStack[1..6] | Where-Object { $_ }) -join ' > ')
                continue
            }
        }
        $null = $buffer.AppendLine($line)
    }
    . $flush

    foreach ($section in $sections) {
        if ($section.text.Length -le $MaxChars) {
            $section
            continue
        }
        foreach ($piece in (Split-McpTextBySize -Text $section.text -MaxChars $MaxChars)) {
            [ordered]@{ heading = $section.heading; text = $piece }
        }
    }
}

function Split-McpTextBySize {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string] $Text,

        [int] $MaxChars = 1500
    )

    # Paragraphs first; paragraphs that are still too long are split by lines, then hard-wrapped.
    $units = [System.Collections.Generic.List[string]]::new()
    foreach ($paragraph in [regex]::Split($Text, '\n\s*\n')) {
        if ($paragraph.Length -le $MaxChars) {
            $units.Add($paragraph)
            continue
        }
        $lineBuffer = [System.Text.StringBuilder]::new()
        foreach ($line in ($paragraph -split "`n")) {
            if ($line.Length -gt $MaxChars) {
                if ($lineBuffer.Length -gt 0) { $units.Add($lineBuffer.ToString()); $null = $lineBuffer.Clear() }
                for ($offset = 0; $offset -lt $line.Length; $offset += $MaxChars) {
                    $units.Add($line.Substring($offset, [Math]::Min($MaxChars, $line.Length - $offset)))
                }
                continue
            }
            if ($lineBuffer.Length + $line.Length + 1 -gt $MaxChars -and $lineBuffer.Length -gt 0) {
                $units.Add($lineBuffer.ToString())
                $null = $lineBuffer.Clear()
            }
            if ($lineBuffer.Length -gt 0) { $null = $lineBuffer.Append("`n") }
            $null = $lineBuffer.Append($line)
        }
        if ($lineBuffer.Length -gt 0) { $units.Add($lineBuffer.ToString()) }
    }

    $chunks = [System.Collections.Generic.List[string]]::new()
    $current = [System.Text.StringBuilder]::new()
    foreach ($unit in $units) {
        $trimmed = $unit.Trim()
        if (-not $trimmed) { continue }
        if ($current.Length -gt 0 -and $current.Length + $trimmed.Length + 2 -gt $MaxChars) {
            $chunks.Add($current.ToString())
            $null = $current.Clear()
        }
        if ($current.Length -gt 0) { $null = $current.Append("`n`n") }
        $null = $current.Append($trimmed)
    }
    if ($current.Length -gt 0) { $chunks.Add($current.ToString()) }
    , $chunks.ToArray()
}

function New-McpChunkIndex {
    <#
    .SYNOPSIS
        Chunks a document and pre-computes the term frequencies used by the BM25 search.
    #>
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string] $Content,

        [AllowEmptyString()]
        [string] $Title = ''
    )

    $titleTokens = Get-McpToken -Text $Title
    $chunks = [System.Collections.Generic.List[object]]::new()
    foreach ($section in (Split-McpMarkdownSection -Content $Content)) {
        $tf = @{}
        $length = 0
        foreach ($token in (Get-McpToken -Text $section.text)) {
            $tf[$token] = [int]$tf[$token] + 1
            $length++
        }
        if ($length -eq 0) { continue }
        foreach ($token in (Get-McpToken -Text $section.heading)) {
            $tf[$token] = [int]$tf[$token] + 2
            $length += 2
        }
        foreach ($token in $titleTokens) {
            $tf[$token] = [int]$tf[$token] + 1
            $length++
        }
        $chunks.Add([ordered]@{
                heading = $section.heading
                text    = $section.text
                len     = $length
                tf      = $tf
            })
    }
    , $chunks.ToArray()
}
