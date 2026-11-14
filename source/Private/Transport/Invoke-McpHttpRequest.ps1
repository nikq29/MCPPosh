function Invoke-McpHttpRequest {
    <#
    .SYNOPSIS
        Handles one HTTP request and returns the status code that was sent.

    .DESCRIPTION
        Handles one request of the HTTP transport: / (information), /health (status, details only when authorized) and /mcp (origin check, API key check, protocol version check, Content-Type application/json (415 otherwise), body limit of 10 MB counted while reading (413), JSON-RPC over POST, 202 for notifications, 405 for GET and DELETE). Returns the HTTP status code that was sent.

    .PARAMETER Context
        The server context created by New-McpServerContext.

    .PARAMETER HttpContext
        The HttpListenerContext of the request to handle.

    .PARAMETER Settings
        Hashtable with the configured ApiKeys, AllowedOrigins and IsLoopback flag.

    .EXAMPLE
        $status = Invoke-McpHttpRequest -Context $context -HttpContext $listener.GetContext() -Settings $settings

        Handles the next request and returns its status code.
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
            # Only JSON is accepted. This also stops cross-site "simple" requests (text/plain, form data)
            # that browsers send without a CORS preflight.
            $mediaType = ([string]$request.ContentType -split ';')[0].Trim().ToLowerInvariant()
            if ($mediaType -ne 'application/json') {
                Send-McpHttpResponse -Response $response -StatusCode 415 -Headers $corsHeaders -Body '{"error":"Content-Type must be application/json"}'
                return 415
            }
            if ($request.ContentLength64 -gt $script:McpMaxRequestBytes) {
                Send-McpHttpResponse -Response $response -StatusCode 413 -Headers $corsHeaders -Body '{"error":"Request too large"}'
                return 413
            }

            # Count the bytes while reading: chunked requests have no Content-Length.
            $buffer = [System.IO.MemoryStream]::new()
            try {
                $null = Copy-McpStreamWithLimit -Source $request.InputStream -Destination $buffer -MaxBytes $script:McpMaxRequestBytes -Description 'request body'
            }
            catch [System.IO.InvalidDataException] {
                Send-McpHttpResponse -Response $response -StatusCode 413 -Headers $corsHeaders -Body '{"error":"Request too large"}'
                return 413
            }
            $buffer.Position = 0
            $reader = [System.IO.StreamReader]::new($buffer, $script:Utf8NoBom)
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
