function ConvertTo-McpJson {
    <#
    .SYNOPSIS
        Serializes an object to JSON without unrolling arrays and without depth warnings.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowNull()]
        [object] $InputObject,

        [switch] $Compress
    )

    ConvertTo-Json -InputObject $InputObject -Depth 64 -Compress:$Compress -WarningAction SilentlyContinue
}
