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
    .EXAMPLE
        Get-McpServer -Uri https://mcpposh.azurecontainerapps.io/mcp -ApiKey $key | Format-List
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

function Get-McpRemoteServerStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri] $Uri,

        [string] $ApiKey
    )

    $endpoint = Resolve-McpEndpointUri -Uri $Uri
    $healthUrl = $endpoint.AbsoluteUri -replace '/mcp/?$', '/health'
    $headers = @{}
    if ($ApiKey) { $headers['Authorization'] = "Bearer $ApiKey" }

    $status = 'Unreachable'
    $health = $null
    $errorMessage = $null
    try {
        $response = Invoke-WebRequest -Uri $healthUrl -Headers $headers -TimeoutSec 15 -SkipHttpErrorCheck -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $health = ConvertFrom-McpJson -Json ([string]$response.Content)
            $status = if ($health.Contains('documents')) { 'Running' } elseif ($ApiKey) { 'Unauthorized' } else { 'Running' }
        }
        else {
            $status = "HTTP $($response.StatusCode)"
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
    }

    [pscustomobject]@{
        PSTypeName    = 'MCPPosh.Server'
        KnowledgeBase = if ($health) { [string]$health['knowledgeBase'] } else { $null }
        Transport     = 'Http'
        Status        = $status
        Url           = $endpoint.AbsoluteUri
        Port          = $endpoint.Port
        ProcessId     = $null
        Documents     = if ($health -and $health.Contains('documents')) { [int]$health['documents'] } else { $null }
        Revision      = if ($health -and $health.Contains('revision')) { [long]$health['revision'] } else { $null }
        Uptime        = if ($health -and $health.Contains('uptimeSeconds')) { [timespan]::FromSeconds([double]$health['uptimeSeconds']) } else { $null }
        AuthRequired  = if ($health -and $health.Contains('authRequired')) { [bool]$health['authRequired'] } else { $null }
        AllowWrite    = if ($health -and $health.Contains('allowWrite')) { [bool]$health['allowWrite'] } else { $null }
        Version       = if ($health) { [string]$health['version'] } else { $null }
        Error         = $errorMessage
    }
}

function Resolve-McpEndpointUri {
    <#
    .SYNOPSIS
        Normalizes a server URL to its /mcp endpoint (accepts the base URL or the endpoint).
    #>
    [CmdletBinding()]
    [OutputType([uri])]
    param(
        [Parameter(Mandatory)]
        [uri] $Uri
    )

    if (-not $Uri.IsAbsoluteUri) {
        throw "'$Uri' is not an absolute URL."
    }
    $text = $Uri.AbsoluteUri.TrimEnd('/')
    if ($text -notmatch '/mcp$') { $text += '/mcp' }
    [uri]$text
}
