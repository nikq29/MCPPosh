function New-McpErrorResponse {
    <#
    .SYNOPSIS
        Creates a JSON-RPC error response.

    .DESCRIPTION
        Creates a JSON-RPC 2.0 error response with the request id, the error code, the message and optional data, ready to be serialized with ConvertTo-McpJson.

    .PARAMETER Id
        Id of the request the error belongs to, or $null when the id is unknown (parse errors).

    .PARAMETER Code
        The JSON-RPC error code, for example -32601 for method not found.

    .PARAMETER Message
        Short description of the error that is sent to the client.

    .PARAMETER Data
        Optional additional information about the error, for example the requested URI.

    .EXAMPLE
        New-McpErrorResponse -Id 7 -Code -32601 -Message 'Method not found: foo'

        Returns the error response for request 7.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an in-memory response object only; no system state is changed.')]
    param(
        [AllowNull()]
        [object] $Id,

        [Parameter(Mandatory)]
        [int] $Code,

        [Parameter(Mandatory)]
        [string] $Message,

        [object] $Data
    )

    $errorObject = [ordered]@{ code = $Code; message = $Message }
    if ($null -ne $Data) { $errorObject['data'] = $Data }
    [ordered]@{ jsonrpc = '2.0'; id = $Id; error = $errorObject }
}
