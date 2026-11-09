function Test-McpLooksLikePath {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $Value
    )

    [System.IO.Path]::IsPathRooted($Value) -or $Value.Contains('/') -or $Value.Contains('\') -or $Value.StartsWith('.')
}
