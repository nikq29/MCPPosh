function Get-McpMarkdownTitle {
    <#
    .SYNOPSIS
        Returns the first level-one heading of a Markdown text.

    .DESCRIPTION
        Searches a Markdown text for the first level-one heading (# Title) and returns its text, or $null when there is none.

    .PARAMETER Markdown
        The Markdown text to search for a level-one heading.

    .EXAMPLE
        Get-McpMarkdownTitle -Markdown "Intro

        # Installation

        Text"

        Returns: Installation
    #>
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
