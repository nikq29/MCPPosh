function Invoke-McpToolCall {
    <#
    .SYNOPSIS
        Handles the MCP method tools/call.

    .DESCRIPTION
        Validates the tool name and arguments of a tools/call request and runs the tool. Unknown tools are protocol errors; failures while running a tool are returned as tool results with isError so the model can react.

    .PARAMETER Context
        The server context created by New-McpServerContext.

    .PARAMETER Params
        The params object of the request with the tool name and its arguments.

    .EXAMPLE
        Invoke-McpToolCall -Context $context -Params ([ordered]@{ name = 'list_documents'; arguments = [ordered]@{} })

        Runs list_documents and returns its tool result.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Context,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Params
    )

    $name = $Params['name']
    if ($name -isnot [string] -or -not $name) {
        throw (New-McpRpcError -Code -32602 -Message 'Invalid params: tool name is required')
    }
    $arguments = $Params['arguments']
    if ($null -eq $arguments) { $arguments = [ordered]@{} }
    if ($arguments -isnot [System.Collections.IDictionary]) {
        throw (New-McpRpcError -Code -32602 -Message 'Invalid params: arguments must be an object')
    }

    $known = @('search_documentation', 'get_document', 'list_documents')
    if ($Context.AllowWrite) { $known += 'add_note' }
    if ($known -notcontains $name) {
        throw (New-McpRpcError -Code -32602 -Message "Unknown tool: $name")
    }

    try {
        switch ($name) {
            'search_documentation' { Invoke-McpSearchTool -Context $Context -Arguments $arguments }
            'get_document' { Invoke-McpGetDocumentTool -Context $Context -Arguments $arguments }
            'list_documents' { Invoke-McpListDocumentsTool -Context $Context -Arguments $arguments }
            'add_note' { Invoke-McpAddNoteTool -Context $Context -Arguments $arguments }
        }
    }
    catch {
        # Tool execution errors are reported to the model (isError) so it can correct itself.
        # Only argument errors (written for the model) are passed on; unexpected exceptions can contain
        # file system paths or other internals and stay in the server log.
        $exception = $_.Exception
        if ($exception -is [System.ArgumentException]) {
            Write-McpLog -Context $Context -Level WARN -Message "Tool $name failed: $($exception.Message)"
            New-McpToolResult -Text "Error: $($exception.Message)" -IsError
        }
        else {
            Write-McpLog -Context $Context -Level ERROR -Message "Tool $name failed: $($exception.GetType().FullName): $($exception.Message)"
            New-McpToolResult -Text "Error: the tool $name failed because of an internal error." -IsError
        }
    }
}
