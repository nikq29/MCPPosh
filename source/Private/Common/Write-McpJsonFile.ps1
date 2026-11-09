function Write-McpJsonFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $InputObject
    )

    Write-McpTextFile -Path $Path -Content (ConvertTo-McpJson -InputObject $InputObject)
}
