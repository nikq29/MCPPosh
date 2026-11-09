function Start-McpHttpServer {
    <#
    .SYNOPSIS
        Runs the MCP Streamable HTTP transport (JSON responses, stateless) until stopped.

    .DESCRIPTION
        Runs the MCP Streamable HTTP transport with HttpListener until it is stopped: writes the server state file, serves /mcp, /health and /, and removes the state file on exit. Responses are JSON (no server-initiated SSE stream) and the server is stateless.

    .PARAMETER Context
        The server context created by New-McpServerContext.

    .PARAMETER Port
        TCP port the HTTP listener binds to, for example 5050 or 8080.

    .PARAMETER ListenAddress
        localhost for local connections only, * for all interfaces, or a specific host name.

    .PARAMETER ApiKeys
        API keys accepted as Bearer token or X-API-Key header. Without keys no authentication is required.

    .PARAMETER AllowedOrigins
        Browser origins allowed for CORS. Other origins are rejected on /mcp.

    .PARAMETER AllowAnonymous
        Records that the server was started without API key on a non-loopback address on purpose.

    .EXAMPLE
        Start-McpHttpServer -Context $context -Port 5050 -ListenAddress localhost -ApiKeys 'secret-key'

        Serves http://localhost:5050/mcp until Ctrl+C is pressed.
    #>
    [CmdletBinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal helper; the public cmdlet Start-McpServer implements ShouldProcess.')]
    param(
        [Parameter(Mandatory)]
        [object] $Context,

        [Parameter(Mandatory)]
        [int] $Port,

        [string] $ListenAddress = 'localhost',

        [AllowEmptyCollection()]
        [string[]] $ApiKeys = @(),

        [AllowEmptyCollection()]
        [string[]] $AllowedOrigins = @(),

        [switch] $AllowAnonymous
    )

    $ApiKeys = [string[]]@($ApiKeys | Where-Object { $_ })
    $AllowedOrigins = [string[]]@($AllowedOrigins | Where-Object { $_ })
    $isLoopback = Test-McpLoopbackAddress -Address $ListenAddress
    $prefixHost = if ($isLoopback) { 'localhost' } elseif ($ListenAddress -in '*', '+', '0.0.0.0', '::') { '+' } else { $ListenAddress }
    $displayHost = if ($prefixHost -eq '+') { 'localhost' } else { $prefixHost }

    $listener = [System.Net.HttpListener]::new()
    $listener.Prefixes.Add("http://${prefixHost}:$Port/")
    $listener.IgnoreWriteExceptions = $true
    try {
        $listener.Start()
    }
    catch {
        throw "Could not listen on http://${prefixHost}:$Port/ : $($_.Exception.Message)"
    }

    $kb = $Context.KnowledgeBase
    $stateFile = Get-McpServerStateFile -KnowledgeBaseName $kb.Name -Port $Port
    Write-McpJsonFile -Path $stateFile -InputObject ([ordered]@{
            pid              = $PID
            processStartTime = Get-McpProcessStartTime -ProcessId $PID
            knowledgeBase    = $kb.Name
            kbPath           = $kb.Path
            transport        = 'Http'
            port             = $Port
            listenAddress    = $ListenAddress
            url              = "http://${displayHost}:$Port/mcp"
            allowWrite       = [bool]$Context.AllowWrite
            authRequired     = ($ApiKeys.Count -gt 0)
            allowAnonymous   = [bool]$AllowAnonymous
            allowedOrigins   = $AllowedOrigins
            logFile          = $Context.LogPath
            startedAt        = Get-McpUtcNow
            version          = $script:ModuleVersion
        })

    $null = Update-McpServerIndex -Context $Context -Force
    Write-McpLog -Context $Context -Message ("HTTP server for knowledge base '{0}' listening on http://{1}:{2}/mcp (pid {3}, MCPPosh {4}, auth: {5}, write access: {6})" -f $kb.Name, $prefixHost, $Port, $PID, $script:ModuleVersion, $(if ($ApiKeys.Count) { 'API key' } else { 'none' }), $Context.AllowWrite)

    $settings = @{
        ApiKeys        = $ApiKeys
        AllowedOrigins = $AllowedOrigins
        IsLoopback     = $isLoopback
    }

    try {
        while ($listener.IsListening) {
            $pending = $listener.GetContextAsync()
            # Short waits keep the loop responsive to Ctrl+C.
            while (-not $pending.AsyncWaitHandle.WaitOne(250)) { }
            if ($pending.IsFaulted -or $pending.IsCanceled) {
                if (-not $listener.IsListening) { break }
                Write-McpLog -Context $Context -Level WARN -Message "Failed to accept request: $($pending.Exception.InnerException.Message)"
                continue
            }
            $httpContext = $pending.Result
            $watch = [System.Diagnostics.Stopwatch]::StartNew()
            $status = 500
            try {
                $status = Invoke-McpHttpRequest -Context $Context -HttpContext $httpContext -Settings $settings
            }
            catch {
                Write-McpLog -Context $Context -Level ERROR -Message "Unhandled error: $($_.Exception.Message)"
                try { Send-McpHttpResponse -Response $httpContext.Response -StatusCode 500 -Body '{"error":"Internal server error"}' } catch { $null = $_ }
            }
            finally {
                try { $httpContext.Response.Close() } catch { $null = $_ }
            }
            Write-McpLog -Context $Context -Level DEBUG -Message ('{0} {1} -> {2} ({3} ms, {4})' -f $httpContext.Request.HttpMethod, $httpContext.Request.Url.AbsolutePath, $status, $watch.ElapsedMilliseconds, $httpContext.Request.RemoteEndPoint)
        }
    }
    finally {
        try { $listener.Stop() } catch { $null = $_ }
        $listener.Close()
        $state = Read-McpJsonFile -Path $stateFile -ErrorAction SilentlyContinue
        if ($state -and [int]$state.pid -eq $PID) {
            Remove-Item -LiteralPath $stateFile -Force -ErrorAction SilentlyContinue
        }
        Write-McpLog -Context $Context -Message 'HTTP server stopped'
    }
}
