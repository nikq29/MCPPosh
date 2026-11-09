function New-McpRpcError {
    <#
    .SYNOPSIS
        Creates an exception carrying a JSON-RPC error code.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int] $Code,

        [Parameter(Mandatory)]
        [string] $Message,

        [object] $Data
    )

    $exception = [System.InvalidOperationException]::new($Message)
    $exception.Data['McpRpcCode'] = $Code
    if ($null -ne $Data) { $exception.Data['McpRpcData'] = $Data }
    $exception
}
