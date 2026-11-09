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
