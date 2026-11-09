function Test-McpLooksLikePath {
    <#
    .SYNOPSIS
        Tests whether a value should be treated as a path.

    .DESCRIPTION
        Returns $true when the value is a rooted path, contains a slash or backslash, or starts with a dot. Such values are treated as knowledge base directories instead of names.

    .PARAMETER Value
        The value passed to a -KnowledgeBase or -Name parameter, either a name or a path.

    .EXAMPLE
        Test-McpLooksLikePath -Value 'Z:\mcpposh\Shared'

        Returns $true.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $Value
    )

    [System.IO.Path]::IsPathRooted($Value) -or $Value.Contains('/') -or $Value.Contains('\') -or $Value.StartsWith('.')
}
