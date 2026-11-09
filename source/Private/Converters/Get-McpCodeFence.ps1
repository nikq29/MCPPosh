function Get-McpCodeFence {
    <#
    .SYNOPSIS
        Returns a code fence that is longer than any fence in the code.

    .DESCRIPTION
        Returns a backtick code fence of at least three characters that is longer than the longest backtick sequence in the given code, so the code can be wrapped safely in a fenced block.

    .PARAMETER Text
        The code that will be wrapped in the fenced code block.

    .EXAMPLE
        Get-McpCodeFence -Text 'Write-Output 1'

        Returns three backticks.
    #>
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
