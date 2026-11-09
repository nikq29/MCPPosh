function Start-McpHttpServer {
    <#
    .SYNOPSIS
        Runs the MCP Streamable HTTP transport (JSON responses, stateless) until stopped.
    .DESCRIPTION
        Endpoints:
          POST /mcp     JSON-RPC requests (200 + JSON) and notifications (202)
          GET  /mcp     405 (no server-initiated SSE stream)
          GET  /health  liveness probe; details only for authorized callers
    #>
    [CmdletBinding()]
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

function Send-McpHttpResponse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Net.HttpListenerResponse] $Response,

        [Parameter(Mandatory)]
        [int] $StatusCode,

        [AllowEmptyString()]
        [string] $Body = '',

        [string] $ContentType = 'application/json; charset=utf-8',

        [hashtable] $Headers = @{}
    )

    $Response.StatusCode = $StatusCode
    foreach ($header in $Headers.GetEnumerator()) {
        $Response.Headers[$header.Key] = [string]$header.Value
    }
    $Response.Headers['Cache-Control'] = 'no-store'
    $Response.Headers['X-Content-Type-Options'] = 'nosniff'
    if ($Body) {
        $bytes = $script:Utf8NoBom.GetBytes($Body)
        $Response.ContentType = $ContentType
        $Response.ContentLength64 = $bytes.Length
        $Response.OutputStream.Write($bytes, 0, $bytes.Length)
    }
    else {
        $Response.ContentLength64 = 0
    }
}

function Test-McpOriginAllowed {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()]
        [string] $Origin,

        [Parameter(Mandatory)]
        [hashtable] $Settings
    )

    if (-not $Origin -or $Origin -eq 'null') { return (-not $Origin) }
    if ($Settings.AllowedOrigins -contains $Origin) { return $true }
    if ($Settings.AllowedOrigins.Count -gt 0) { return $false }
    if ($Settings.IsLoopback) {
        # Protect local servers against DNS rebinding: only local web pages may call them.
        try {
            $originHost = ([uri]$Origin).Host.Trim('[', ']')
            return $originHost -in 'localhost', '127.0.0.1', '::1'
        }
        catch {
            return $false
        }
    }
    $true
}

function Invoke-McpHttpRequest {
    <#
    .SYNOPSIS
        Handles one HTTP request and returns the status code that was sent.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [object] $Context,

        [Parameter(Mandatory)]
        [System.Net.HttpListenerContext] $HttpContext,

        [Parameter(Mandatory)]
        [hashtable] $Settings
    )

    $request = $HttpContext.Request
    $response = $HttpContext.Response
    $path = $request.Url.AbsolutePath.TrimEnd('/')
    if (-not $path) { $path = '/' }
    $method = $request.HttpMethod.ToUpperInvariant()
    $origin = $request.Headers['Origin']

    $corsHeaders = @{}
    if ($origin -and $Settings.AllowedOrigins -contains $origin) {
        $corsHeaders['Access-Control-Allow-Origin'] = $origin
        $corsHeaders['Vary'] = 'Origin'
        $corsHeaders['Access-Control-Allow-Headers'] = 'Content-Type, Accept, Authorization, X-API-Key, Mcp-Session-Id, MCP-Protocol-Version, Last-Event-ID'
        $corsHeaders['Access-Control-Allow-Methods'] = 'GET, POST, DELETE, OPTIONS'
        $corsHeaders['Access-Control-Expose-Headers'] = 'Mcp-Session-Id'
    }

    $authorized = $Settings.ApiKeys.Count -eq 0 -or (Test-McpApiKey -AuthorizationHeader $request.Headers['Authorization'] -ApiKeyHeader $request.Headers['X-API-Key'] -ApiKeys $Settings.ApiKeys)

    switch ($path) {
        '/' {
            if ($method -notin 'GET', 'HEAD') {
                Send-McpHttpResponse -Response $response -StatusCode 405 -Headers @{ Allow = 'GET' }
                return 405
            }
            Send-McpHttpResponse -Response $response -StatusCode 200 -ContentType 'text/plain; charset=utf-8' `
                -Body "MCPPosh MCP server for knowledge base '$($Context.KnowledgeBase.Name)'.`nMCP endpoint (Streamable HTTP): /mcp`nHealth: /health`n"
            return 200
        }

        '/health' {
            if ($method -notin 'GET', 'HEAD') {
                Send-McpHttpResponse -Response $response -StatusCode 405 -Headers @{ Allow = 'GET' }
                return 405
            }
            $health = [ordered]@{ status = 'ok'; server = 'MCPPosh'; version = $script:ModuleVersion }
            if ($authorized) {
                $index = Update-McpServerIndex -Context $Context
                $health['knowledgeBase'] = $Context.KnowledgeBase.Name
                $health['description'] = $Context.KnowledgeBase.Description
                $health['documents'] = $index.Documents.Count
                $health['chunks'] = $index.Chunks.Count
                $health['revision'] = $index.Revision
                $health['allowWrite'] = $Context.AllowWrite
                $health['authRequired'] = $Settings.ApiKeys.Count -gt 0
                $health['uptimeSeconds'] = [long]([datetime]::UtcNow - $Context.StartedAt).TotalSeconds
                $health['requests'] = $Context.RequestCount
            }
            Send-McpHttpResponse -Response $response -StatusCode 200 -Body (ConvertTo-McpJson -Compress -InputObject $health)
            return 200
        }

        '/mcp' {
            if (-not (Test-McpOriginAllowed -Origin $origin -Settings $Settings)) {
                Write-McpLog -Context $Context -Level WARN -Message "Rejected request from origin '$origin'"
                Send-McpHttpResponse -Response $response -StatusCode 403 -Body '{"error":"Origin not allowed"}'
                return 403
            }
            if ($method -eq 'OPTIONS') {
                Send-McpHttpResponse -Response $response -StatusCode 204 -Headers ($corsHeaders + @{ Allow = 'POST, OPTIONS' })
                return 204
            }
            if (-not $authorized) {
                Send-McpHttpResponse -Response $response -StatusCode 401 -Headers ($corsHeaders + @{ 'WWW-Authenticate' = 'Bearer realm="MCPPosh"' }) `
                    -Body (ConvertTo-McpJson -Compress -InputObject (New-McpErrorResponse -Id $null -Code -32001 -Message 'Unauthorized: missing or invalid API key'))
                return 401
            }
            if ($method -ne 'POST') {
                # This server does not offer a server-initiated SSE stream or sessions.
                Send-McpHttpResponse -Response $response -StatusCode 405 -Headers ($corsHeaders + @{ Allow = 'POST, OPTIONS' })
                return 405
            }

            $protocolVersion = $request.Headers['MCP-Protocol-Version']
            if ($protocolVersion -and $script:McpSupportedProtocolVersions -notcontains $protocolVersion) {
                Send-McpHttpResponse -Response $response -StatusCode 400 -Headers $corsHeaders `
                    -Body (ConvertTo-McpJson -Compress -InputObject (New-McpErrorResponse -Id $null -Code -32600 -Message "Unsupported MCP-Protocol-Version: $protocolVersion"))
                return 400
            }
            if ($request.ContentLength64 -gt 10MB) {
                Send-McpHttpResponse -Response $response -StatusCode 413 -Headers $corsHeaders -Body '{"error":"Request too large"}'
                return 413
            }

            $reader = [System.IO.StreamReader]::new($request.InputStream, $script:Utf8NoBom)
            try { $body = $reader.ReadToEnd() } finally { $reader.Dispose() }

            $json = Invoke-McpMessage -Context $Context -Json $body
            if ($null -eq $json) {
                Send-McpHttpResponse -Response $response -StatusCode 202 -Headers $corsHeaders
                return 202
            }
            Send-McpHttpResponse -Response $response -StatusCode 200 -Headers $corsHeaders -Body $json
            return 200
        }

        default {
            Send-McpHttpResponse -Response $response -StatusCode 404 -Body '{"error":"Not found"}'
            return 404
        }
    }
}
