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
