function ConvertFrom-McpTextFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    @{ Content = Read-McpTextFile -Path $Path }
}
