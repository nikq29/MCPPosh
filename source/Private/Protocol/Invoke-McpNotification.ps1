function Invoke-McpNotification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Context,

        [Parameter(Mandatory)]
        [string] $Method,

        [object] $Params
    )

    switch ($Method) {
        'notifications/initialized' { Write-McpLog -Context $Context -Message 'Client initialized' }
        'notifications/cancelled' { Write-McpLog -Context $Context -Level DEBUG -Message 'Client cancelled a request' }
        default { Write-McpLog -Context $Context -Level DEBUG -Message "Ignored notification: $Method" }
    }
}
