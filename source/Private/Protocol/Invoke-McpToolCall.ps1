function Invoke-McpToolCall {
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
        Write-McpLog -Context $Context -Level WARN -Message "Tool $name failed: $($_.Exception.Message)"
        New-McpToolResult -Text "Error: $($_.Exception.Message)" -IsError
    }
}
