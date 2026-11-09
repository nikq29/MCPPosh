function Stop-McpServer {
    <#
    .SYNOPSIS
        Stops MCPPosh HTTP servers that run on this machine.

    .DESCRIPTION
        Stops MCPPosh HTTP servers that run on this machine, in the background or in another console, and removes their state files. Without parameters the only running server is stopped.

    .PARAMETER KnowledgeBase
        Stop the servers of this knowledge base.

    .PARAMETER Port
        Stop the server on this port.

    .PARAMETER All
        Stops all MCPPosh HTTP servers that were started on this machine.

    .EXAMPLE
        Stop-McpServer -KnowledgeBase Contoso

    .EXAMPLE
        Get-McpServer | Stop-McpServer
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Filter')]
    param(
        [Parameter(Position = 0, ParameterSetName = 'Filter', ValueFromPipelineByPropertyName)]
        [string] $KnowledgeBase,

        [Parameter(ParameterSetName = 'Filter', ValueFromPipelineByPropertyName)]
        [int] $Port,

        [Parameter(Mandatory, ParameterSetName = 'All')]
        [switch] $All
    )

    process {
        $states = @(Get-McpServerState)
        if (-not $All) {
            if (-not $KnowledgeBase -and -not $Port) {
                $running = @($states | Where-Object Status -EQ 'Running')
                if ($running.Count -gt 1) {
                    Write-Error -Message 'Several MCP servers are running. Specify -KnowledgeBase, -Port or -All.' -Category InvalidArgument
                    return
                }
                $states = $running
            }
            else {
                $states = @($states | Where-Object {
                        (-not $KnowledgeBase -or $_.knowledgeBase -like $KnowledgeBase -or $_.kbPath -eq $KnowledgeBase) -and
                        (-not $Port -or [int]$_.port -eq $Port)
                    })
            }
        }

        if ($states.Count -eq 0) {
            if ($KnowledgeBase -or $Port) {
                Write-Error -Message 'No matching MCP server found.' -Category ObjectNotFound
            }
            return
        }

        foreach ($state in $states) {
            $label = "knowledge base '$($state.knowledgeBase)' on port $($state.port) (pid $($state.pid))"
            if ($state.Status -ne 'Running') {
                Remove-Item -LiteralPath $state.StateFile -Force -ErrorAction SilentlyContinue
                continue
            }
            if (-not $PSCmdlet.ShouldProcess($label, 'Stop MCP server')) { continue }
            try {
                $process = [System.Diagnostics.Process]::GetProcessById([int]$state.pid)
                $process.Kill($true)
                $null = $process.WaitForExit(10000)
            }
            catch {
                Write-Verbose "Process $($state.pid) already exited: $($_.Exception.Message)"
            }
            Remove-Item -LiteralPath $state.StateFile -Force -ErrorAction SilentlyContinue
            Write-Verbose "Stopped MCP server for $label"
        }
    }
}
