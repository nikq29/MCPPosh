function Invoke-McpNotification {
    <#
    .SYNOPSIS
        Handles an MCP notification from the client.

    .DESCRIPTION
        Handles JSON-RPC notifications such as notifications/initialized and notifications/cancelled by logging them. Notifications never produce a response.

    .PARAMETER Context
        The server context created by New-McpServerContext.

    .PARAMETER Method
        The notification method, for example notifications/initialized.

    .PARAMETER Params
        The params object of the notification, for example with the requestId of a cancelled request.

    .EXAMPLE
        Invoke-McpNotification -Context $context -Method 'notifications/initialized'

        Writes Client initialized to the server log.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Context,

        [Parameter(Mandatory)]
        [string] $Method,

        [object] $Params
    )

    $requestId = if ($Params -is [System.Collections.IDictionary]) { $Params['requestId'] } else { $null }
    switch ($Method) {
        'notifications/initialized' { Write-McpLog -Context $Context -Message 'Client initialized' }
        'notifications/cancelled' { Write-McpLog -Context $Context -Level DEBUG -Message "Client cancelled request '$requestId'" }
        default { Write-McpLog -Context $Context -Level DEBUG -Message "Ignored notification: $Method" }
    }
}
