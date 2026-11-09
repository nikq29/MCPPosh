function Restart-McpServer {
    <#
    .SYNOPSIS
        Restarts local MCPPosh HTTP servers with their previous settings.
    .DESCRIPTION
        API keys are never stored. If the server required an API key, pass -ApiKey again or set
        $env:MCPPOSH_API_KEY.
    .EXAMPLE
        Restart-McpServer -KnowledgeBase Contoso
    .EXAMPLE
        Restart-McpServer -Port 8080 -ApiKey $key
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('MCPPosh.Server')]
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
            $keys = if ($ApiKey) { $ApiKey } elseif ($env:MCPPOSH_API_KEY) { $env:MCPPOSH_API_KEY -split ',' } else { @() }
            if ($state.authRequired -and @($keys).Count -eq 0) {
                Write-Error -Message "The server on port $($state.port) requires an API key. Pass -ApiKey or set `$env:MCPPOSH_API_KEY." -Category InvalidArgument
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
            if (@($state.allowedOrigins).Count -gt 0) { $startParams['AllowedOrigin'] = [string[]]@($state.allowedOrigins) }
            Start-McpServer @startParams
        }
    }
}
