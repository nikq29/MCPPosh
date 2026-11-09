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
