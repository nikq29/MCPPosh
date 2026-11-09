function Invoke-McpInitialize {
    <#
    .SYNOPSIS
        Handles the MCP method initialize.

    .DESCRIPTION
        Negotiates the protocol version (the requested version when supported, otherwise the newest), records the client information and returns the server capabilities (tools, resources), the server information and the instructions.

    .PARAMETER Context
        The server context created by New-McpServerContext.

    .PARAMETER Params
        The params object of the initialize request with protocolVersion, capabilities and clientInfo.

    .EXAMPLE
        Invoke-McpInitialize -Context $context -Params ([ordered]@{ protocolVersion = '2025-06-18' })

        Returns the initialize result for protocol version 2025-06-18.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
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
        instructions    = Get-McpServerInstruction -Context $Context
    }
}
