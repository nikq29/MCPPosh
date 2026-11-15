function Invoke-McpMessage {
    <#
    .SYNOPSIS
        Handles one raw JSON-RPC message (single request, notification or batch).

    .DESCRIPTION
        Parses one raw JSON-RPC message from a transport, dispatches a single request, a notification or a batch, and returns the serialized response. Returns $null when nothing has to be sent back; invalid JSON results in a parse error response.

    .PARAMETER Context
        The server context created by New-McpServerContext.

    .PARAMETER Json
        The raw JSON-RPC message as received on stdin or in the HTTP request body.

    .EXAMPLE
        Invoke-McpMessage -Context $context -Json '{"jsonrpc":"2.0","id":1,"method":"ping"}'

        Returns {"jsonrpc":"2.0","id":1,"result":{}}.

    .OUTPUTS
        The JSON response text, or $null when nothing has to be sent back (notifications).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Context,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Json
    )

    try {
        $message = ConvertFrom-McpJson -Json $Json
    }
    catch {
        Write-McpLog -Context $Context -Level WARN -Message "Parse error: $($_.Exception.Message)"
        return ConvertTo-McpJson -Compress -InputObject (New-McpErrorResponse -Id $null -Code -32700 -Message 'Parse error')
    }

    if ($message -is [array]) {
        if ($message.Count -eq 0) {
            return ConvertTo-McpJson -Compress -InputObject (New-McpErrorResponse -Id $null -Code -32600 -Message 'Invalid Request: empty batch')
        }
        if ($message.Count -gt $script:McpMaxBatchSize) {
            return ConvertTo-McpJson -Compress -InputObject (New-McpErrorResponse -Id $null -Code -32600 -Message "Invalid Request: a batch must not contain more than $($script:McpMaxBatchSize) messages")
        }
        $responses = [System.Collections.Generic.List[object]]::new()
        foreach ($item in $message) {
            $response = Invoke-McpRequest -Context $Context -Message $item
            if ($null -ne $response) { $responses.Add($response) }
        }
        if ($responses.Count -eq 0) { return $null }
        return ConvertTo-McpJson -Compress -InputObject $responses.ToArray()
    }

    $single = Invoke-McpRequest -Context $Context -Message $message
    if ($null -eq $single) { return $null }
    ConvertTo-McpJson -Compress -InputObject $single
}
