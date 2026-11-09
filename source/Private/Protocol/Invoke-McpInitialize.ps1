function Invoke-McpInitialize {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Context,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Params
    )

    $requested = [string]$Params['protocolVersion']
    $version = if ($requested -and $script:McpSupportedProtocolVersions -contains $requested) {
        $requested
    }
    else {
        $script:McpSupportedProtocolVersions[0]
    }
    $Context.ProtocolVersion = $version
    $Context.ClientInfo = $Params['clientInfo']

    $clientName = if ($Params['clientInfo']) { '{0} {1}' -f $Params['clientInfo']['name'], $Params['clientInfo']['version'] } else { 'unknown client' }
    Write-McpLog -Context $Context -Message "initialize from $clientName (requested $requested, using $version)"

    $null = Update-McpServerIndex -Context $Context
    $kb = $Context.KnowledgeBase
    [ordered]@{
        protocolVersion = $version
        capabilities    = [ordered]@{
            tools     = [ordered]@{ listChanged = $false }
            resources = [ordered]@{ subscribe = $false; listChanged = $false }
        }
        serverInfo      = [ordered]@{
            name    = 'MCPPosh'
            title   = "MCPPosh - $($kb.Name)"
            version = $script:ModuleVersion
        }
        instructions    = Get-McpServerInstructions -Context $Context
    }
}
