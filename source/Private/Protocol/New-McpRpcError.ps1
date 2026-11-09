function New-McpRpcError {
    <#
    .SYNOPSIS
        Creates an exception carrying a JSON-RPC error code.

    .DESCRIPTION
        Creates an InvalidOperationException whose Data contains the JSON-RPC error code (and optional data). Handlers throw it and Invoke-McpRequest turns it into an error response with that code.

    .PARAMETER Code
        The JSON-RPC error code, for example -32602 for invalid params or -32002 for resource not found.

    .PARAMETER Message
        Short description of the error that is sent to the client.

    .PARAMETER Data
        Optional additional information that is sent as the data member of the error.

    .EXAMPLE
        throw (New-McpRpcError -Code -32602 -Message 'Invalid params: uri is required')

        Results in a JSON-RPC error with code -32602.
    #>
    [CmdletBinding()]
    [OutputType([System.InvalidOperationException])]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an exception object only; no system state is changed.')]
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
