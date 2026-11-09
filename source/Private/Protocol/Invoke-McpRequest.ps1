function Invoke-McpRequest {
    <#
    .SYNOPSIS
        Validates and dispatches a parsed JSON-RPC message.

    .DESCRIPTION
        Validates a parsed JSON-RPC message (version, method, id and params) and dispatches it to the handler of the MCP method. Handler exceptions become JSON-RPC errors with the code carried by New-McpRpcError, or internal errors.

    .PARAMETER Context
        The server context created by New-McpServerContext.

    .PARAMETER Message
        The parsed JSON-RPC message, an ordered dictionary as returned by ConvertFrom-McpJson.

    .EXAMPLE
        Invoke-McpRequest -Context $context -Message ([ordered]@{ jsonrpc = '2.0'; id = 1; method = 'tools/list' })

        Returns the response dictionary with the tool list.

    .OUTPUTS
        A response dictionary, or $null for notifications and client responses.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory)]
        [object] $Context,

        [AllowNull()]
        [object] $Message
    )

    if ($Message -isnot [System.Collections.IDictionary]) {
        return New-McpErrorResponse -Id $null -Code -32600 -Message 'Invalid Request'
    }

    $hasId = $Message.Contains('id')
    $id = if ($hasId) { $Message['id'] } else { $null }
    $method = $Message['method']

    if ($Message['jsonrpc'] -ne '2.0' -or ($null -ne $method -and $method -isnot [string]) -or ($hasId -and $null -ne $id -and $id -isnot [string] -and $id -isnot [long] -and $id -isnot [int] -and $id -isnot [double])) {
        return New-McpErrorResponse -Id $id -Code -32600 -Message 'Invalid Request'
    }

    if ($null -eq $method) {
        # A response to a server-initiated request; this server sends none, so ignore it.
        return $null
    }

    if (-not $hasId) {
        Invoke-McpNotification -Context $Context -Method $method -Params $Message['params']
        return $null
    }

    $Context.RequestCount++
    $params = $Message['params']
    if ($null -ne $params -and $params -isnot [System.Collections.IDictionary]) {
        return New-McpErrorResponse -Id $id -Code -32602 -Message 'Invalid params: params must be an object'
    }
    if ($null -eq $params) { $params = [ordered]@{} }

    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $result = switch ($method) {
            'initialize' { Invoke-McpInitialize -Context $Context -Params $params; break }
            'ping' { [ordered]@{}; break }
            'tools/list' { Get-McpToolList -Context $Context; break }
            'tools/call' { Invoke-McpToolCall -Context $Context -Params $params; break }
            'resources/list' { Get-McpResourceList -Context $Context -Params $params; break }
            'resources/templates/list' { Get-McpResourceTemplateList -Context $Context; break }
            'resources/read' { Read-McpResource -Context $Context -Params $params; break }
            'prompts/list' { [ordered]@{ prompts = @() }; break }
            'logging/setLevel' { [ordered]@{}; break }
            default { throw (New-McpRpcError -Code -32601 -Message "Method not found: $method") }
        }
        Write-McpLog -Context $Context -Level DEBUG -Message ('{0} ok ({1} ms)' -f $method, $watch.ElapsedMilliseconds)
        [ordered]@{ jsonrpc = '2.0'; id = $id; result = $result }
    }
    catch {
        $exception = $_.Exception
        $code = $exception.Data['McpRpcCode']
        if ($null -eq $code) {
            Write-McpLog -Context $Context -Level ERROR -Message ("{0} failed: {1}" -f $method, $exception.Message)
            return New-McpErrorResponse -Id $id -Code -32603 -Message "Internal error: $($exception.Message)"
        }
        Write-McpLog -Context $Context -Level WARN -Message ("{0} rejected ({1}): {2}" -f $method, $code, $exception.Message)
        New-McpErrorResponse -Id $id -Code ([int]$code) -Message $exception.Message -Data $exception.Data['McpRpcData']
    }
}
