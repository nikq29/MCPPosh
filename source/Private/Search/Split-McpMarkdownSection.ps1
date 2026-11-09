function Split-McpMarkdownSection {
    <#
    .SYNOPSIS
        Splits Markdown into sections by heading, then into chunks of at most MaxChars characters.

    .DESCRIPTION
        Splits Markdown at headings (ignoring headings inside code fences) and returns chunks with the heading path, for example Setup > Requirements. Sections longer than the maximum size are split at paragraph and line boundaries.

    .PARAMETER Content
        The Markdown text to split into sections.

    .PARAMETER MaxChars
        Maximum number of characters per chunk; longer sections are split further.

    .EXAMPLE
        Split-McpMarkdownSection -Content "# A

        Text A

        ## B

        Text B"

        Returns two chunks with the headings A and A > B.

    .OUTPUTS
        Ordered dictionaries with 'heading' (heading path, e.g. "Setup > Requirements") and 'text'.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
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

    foreach ($line in ($Content -split '\r?\n')) {
        $fenceMatch = [regex]::Match($line, '^\s{0,3}(`{3,}|~{3,})')
        if ($fenceMatch.Success) {
            $char = $fenceMatch.Groups[1].Value[0]
            if ($null -eq $fenceChar) { $fenceChar = $char }
            elseif ($fenceChar -eq $char) { $fenceChar = $null }
            $null = $buffer.Append($line).Append("`n")
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
        $null = $buffer.Append($line).Append("`n")
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
