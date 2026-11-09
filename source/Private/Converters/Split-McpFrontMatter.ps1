function Split-McpFrontMatter {
    <#
    .SYNOPSIS
        Separates YAML front matter from Markdown and extracts 'title' and 'tags'.

    .DESCRIPTION
        Separates YAML front matter (between --- lines at the start) from the Markdown body and extracts the title and the tags or keywords, written as an inline list or as a YAML list.

    .PARAMETER Text
        The complete Markdown text, optionally starting with YAML front matter.

    .EXAMPLE
        Split-McpFrontMatter -Text "---
        title: Setup
        tags: [intern, setup]
        ---
        # Setup"

        Returns Body "# Setup", Title "Setup" and Tags intern and setup.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [AllowEmptyString()]
        [string] $Text
    )

    $result = @{ Body = $Text; Title = $null; Tags = @() }
    $match = [regex]::Match($Text, '\A\uFEFF?---[ \t]*\r?\n(?<fm>[\s\S]*?)\r?\n(---|\.\.\.)[ \t]*(\r?\n|\z)')
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
