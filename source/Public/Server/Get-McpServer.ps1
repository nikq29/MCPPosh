function Get-McpServer {
    <#
    .SYNOPSIS
        Shows MCPPosh HTTP servers: local background/foreground servers, or a remote server.

    .DESCRIPTION
        Without -Uri, lists the HTTP servers started on this machine. Servers whose process is
        gone are reported once with Status 'Stopped' and then forgotten.

        With -Uri, queries the /health endpoint of a (remote) server, e.g. one hosted in Azure.

    .PARAMETER KnowledgeBase
        Only servers for this knowledge base.

    .PARAMETER Port
        Only the server on this port.

    .PARAMETER Uri
        Base URL or MCP endpoint of a remote server, e.g. https://docs-mcp.contoso.com/mcp.

    .PARAMETER ApiKey
        API key for the remote server (needed to see details such as the document count).

    .EXAMPLE
        Get-McpServer

        Lists the HTTP servers started on this machine with status, URL and process id.

    .EXAMPLE
        Get-McpServer -Uri https://mcpposh.azurecontainerapps.io/mcp -ApiKey $key | Format-List

        Queries the health endpoint of a hosted server and shows its knowledge base, number of documents, revision and uptime.

    .INPUTS
        MCPPosh.Server. KnowledgeBase and Port bind by property name.

    .OUTPUTS
        MCPPosh.Server: KnowledgeBase, Transport, Status (Running or Stopped), Url, Port, ListenAddress, ProcessId, StartedAt, Uptime, AuthRequired, AllowWrite, AllowAnonymous, AllowedOrigins, LogFile, KnowledgeBasePath and Version. Remote servers (-Uri) additionally report Documents, Revision and Error.

    .LINK
        https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Get-McpServer.md

    .LINK
        Start-McpServer

    .LINK
        Stop-McpServer

    .LINK
        Test-McpServer

    .LINK
        Get-McpServerLog
    #>
    [CmdletBinding(DefaultParameterSetName = 'Local')]
    [OutputType('MCPPosh.Server')]
    param(
        [Parameter(Position = 0, ParameterSetName = 'Local', ValueFromPipelineByPropertyName)]
        [string] $KnowledgeBase,

        [Parameter(ParameterSetName = 'Local', ValueFromPipelineByPropertyName)]
        [int] $Port,

        [Parameter(Mandatory, ParameterSetName = 'Remote')]
        [uri] $Uri,

        [Parameter(ParameterSetName = 'Remote')]
        [string] $ApiKey
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Remote') {
            Get-McpRemoteServerStatus -Uri $Uri -ApiKey $ApiKey
            return
        }

        foreach ($state in (Get-McpServerState | Sort-Object -Property knowledgeBase, port)) {
            if ($KnowledgeBase) {
                $kbMatches = $state.knowledgeBase -like $KnowledgeBase -or $state.kbPath -eq $KnowledgeBase
                if (-not $kbMatches -and (Test-McpLooksLikePath -Value $KnowledgeBase)) {
                    $kbMatches = $state.kbPath -eq [System.IO.Path]::GetFullPath($KnowledgeBase)
                }
                if (-not $kbMatches) { continue }
            }
            if ($Port -and [int]$state.port -ne $Port) { continue }

            $startedAt = ConvertTo-McpDateTime -Value $state.startedAt
            $running = $state.Status -eq 'Running'
            [pscustomobject]@{
                PSTypeName        = 'MCPPosh.Server'
                KnowledgeBase     = [string]$state.knowledgeBase
                Transport         = [string]$state.transport
                Status            = if ($running) { 'Running' } else { 'Stopped' }
                Url               = [string]$state.url
                Port              = [int]$state.port
                ListenAddress     = [string]$state.listenAddress
                ProcessId         = [int]$state.pid
                StartedAt         = $startedAt
                Uptime            = if ($running -and $startedAt) { [datetime]::UtcNow - $startedAt.ToUniversalTime() } else { $null }
                AuthRequired      = [bool]$state.authRequired
                AllowWrite        = [bool]$state.allowWrite
                AllowAnonymous    = [bool]$state.allowAnonymous
                AllowedOrigins    = [string[]]@($state.allowedOrigins | Where-Object { $_ })
                LogFile           = [string]$state.logFile
                KnowledgeBasePath = [string]$state.kbPath
                Version           = [string]$state.version
            }
            if (-not $running) {
                Remove-Item -LiteralPath $state.StateFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
