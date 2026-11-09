function ConvertTo-McpJson {
    <#
    .SYNOPSIS
        Serializes an object to JSON without unrolling arrays and without depth warnings.

    .DESCRIPTION
        Serializes an object with ConvertTo-Json using a depth of 64, without unrolling arrays passed as input and without depth warnings, optionally as compact single-line JSON for JSON-RPC messages.

    .PARAMETER InputObject
        The object to serialize. Arrays are serialized as JSON arrays even with a single element.

    .PARAMETER Compress
        Produces compact JSON on a single line, as required for messages on the stdio transport.

    .EXAMPLE
        ConvertTo-McpJson -InputObject ([ordered]@{ jsonrpc = '2.0'; id = 1; result = @{} }) -Compress

        Returns {"jsonrpc":"2.0","id":1,"result":{}}.
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
