function Invoke-McpMessage {
    <#
    .SYNOPSIS
        Handles one raw JSON-RPC message (single request, notification or batch).
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
