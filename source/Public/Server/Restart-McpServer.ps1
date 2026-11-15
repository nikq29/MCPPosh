function Restart-McpServer {
    <#
    .SYNOPSIS
        Restarts local PSMcpKnowledgeBase HTTP servers with their previous settings.

    .DESCRIPTION
        API keys are never stored. If the server required an API key, pass -ApiKey again or set
        $env:PSMCPKB_API_KEY.
        OAuth settings (issuer, audiences, scope) are not secret; they are stored and reused.

    .PARAMETER KnowledgeBase
        Restart the local HTTP servers of this knowledge base (name, wildcard or directory path).

    .PARAMETER Port
        Restart the local HTTP server that listens on this port.

    .PARAMETER ApiKey
        API keys for the restarted server. Required when the server used API keys, because keys are never stored.

    .EXAMPLE
        Restart-McpServer -KnowledgeBase Contoso

        Restarts the local HTTP server of the knowledge base Contoso with its previous port and options.

    .EXAMPLE
        Restart-McpServer -Port 8080 -ApiKey $key

        Restarts the server on port 8080. API keys are never stored, so servers with authentication need the key again.

    .INPUTS
        PSMcpKnowledgeBase.Server. You can pipe servers from Get-McpServer; KnowledgeBase and Port bind by property name.

    .OUTPUTS
        PSMcpKnowledgeBase.Server: KnowledgeBase, Transport, Status (Running or Stopped), Url, Port, ListenAddress, ProcessId, StartedAt, Uptime, AuthRequired, AllowWrite, AllowAnonymous, AllowedOrigins, LogFile, KnowledgeBasePath and Version.

    .LINK
        https://github.com/nikq29/PSMcpKnowledgeBase/blob/main/docs/en-US/Restart-McpServer.md

    .LINK
        Start-McpServer

    .LINK
        Stop-McpServer

    .LINK
        Get-McpServer
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('PSMcpKnowledgeBase.Server')]
    param(
        [Parameter(Position = 0, ValueFromPipelineByPropertyName)]
        [string] $KnowledgeBase,

        [Parameter(ValueFromPipelineByPropertyName)]
        [int] $Port,

        [string[]] $ApiKey
    )

    process {
        $servers = @(Get-McpServerState | Where-Object {
                (-not $KnowledgeBase -or $_.knowledgeBase -like $KnowledgeBase -or $_.kbPath -eq $KnowledgeBase) -and
                (-not $Port -or [int]$_.port -eq $Port)
            })
        if ($servers.Count -eq 0) {
            Write-Error -Message 'No matching MCP server found.' -Category ObjectNotFound
            return
        }
        if ($servers.Count -gt 1 -and -not $KnowledgeBase -and -not $Port) {
            Write-Error -Message 'Several MCP servers are known. Specify -KnowledgeBase or -Port.' -Category InvalidArgument
            return
        }

        foreach ($state in $servers) {
            $keys = if ($ApiKey) { $ApiKey } elseif ($env:PSMCPKB_API_KEY) { $env:PSMCPKB_API_KEY -split ',' } else { @() }
            # apiKeyRequired is missing in state files of older versions; there authRequired meant an API key.
            $needsKey = if ($null -ne $state.apiKeyRequired) { $state.apiKeyRequired } else { $state.authRequired }
            if ($needsKey -and @($keys).Count -eq 0) {
                Write-Error -Message "The server on port $($state.port) requires an API key. Pass -ApiKey or set `$env:PSMCPKB_API_KEY." -Category InvalidArgument
                continue
            }
            if (-not $PSCmdlet.ShouldProcess("knowledge base '$($state.knowledgeBase)' on port $($state.port)", 'Restart MCP server')) { continue }

            if ($state.Status -eq 'Running') {
                Stop-McpServer -Port ([int]$state.port) -Confirm:$false
            }
            else {
                Remove-Item -LiteralPath $state.StateFile -Force -ErrorAction SilentlyContinue
            }

            $startParams = @{
                KnowledgeBase = [string]$state.kbPath
                Transport     = 'Http'
                Port          = [int]$state.port
                ListenAddress = [string]$state.listenAddress
                Confirm       = $false
            }
            if (@($keys).Count -gt 0) { $startParams['ApiKey'] = [string[]]$keys }
            if ($state.allowWrite) { $startParams['AllowWrite'] = $true }
            if ($state.allowAnonymous) { $startParams['AllowAnonymous'] = $true }
            if ($state.oauthIssuer) {
                $startParams['OAuthIssuer'] = [string]$state.oauthIssuer
                $startParams['OAuthAudience'] = [string[]]@($state.oauthAudience)
                if ($state.oauthScope) { $startParams['OAuthScope'] = [string]$state.oauthScope }
            }
            if (@($state.allowedOrigins).Count -gt 0) { $startParams['AllowedOrigin'] = [string[]]@($state.allowedOrigins) }
            Start-McpServer @startParams
        }
    }
}
