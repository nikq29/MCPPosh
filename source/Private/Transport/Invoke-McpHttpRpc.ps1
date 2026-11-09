function Invoke-McpHttpRpc {
    <#
    .SYNOPSIS
        Minimal MCP Streamable HTTP client: sends one JSON-RPC message and returns the parsed
        response (JSON or SSE). Returns $null for notifications.

    .DESCRIPTION
        Sends one JSON-RPC message to an MCP Streamable HTTP endpoint and returns the parsed response, from a JSON body or from a server-sent event stream. Returns $null for notifications and throws on HTTP errors.

    .PARAMETER Endpoint
        The MCP endpoint URL, for example http://localhost:5050/mcp.

    .PARAMETER Message
        The JSON-RPC message to send, as an ordered dictionary.

    .PARAMETER Headers
        Additional HTTP headers, for example the Authorization header with the API key.

    .PARAMETER TimeoutSeconds
        Seconds to wait for the HTTP response before the request fails.

    .EXAMPLE
        Invoke-McpHttpRpc -Endpoint 'http://localhost:5050/mcp' -Message ([ordered]@{ jsonrpc = '2.0'; id = 1; method = 'ping' })

        Returns the parsed ping response.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri] $Endpoint,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Message,

        [hashtable] $Headers = @{},

        [int] $TimeoutSeconds = 30
    )

    $requestHeaders = @{ Accept = 'application/json, text/event-stream' } + $Headers
    $body = ConvertTo-McpJson -Compress -InputObject $Message
    $response = Invoke-WebRequest -Uri $Endpoint -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -ContentType 'application/json' `
        -Headers $requestHeaders -TimeoutSec $TimeoutSeconds -SkipHttpErrorCheck -UseBasicParsing -ErrorAction Stop

    $content = if ($response.Content -is [byte[]]) { [System.Text.Encoding]::UTF8.GetString($response.Content) } else { [string]$response.Content }
    if ($response.StatusCode -eq 202) { return $null }
    if ($response.StatusCode -eq 401) { throw 'Unauthorized (HTTP 401): missing or invalid API key.' }
    if ($response.StatusCode -ge 400) { throw "HTTP $($response.StatusCode): $content" }
    if (-not $Message.Contains('id')) { return $null }

    $contentType = [string](@($response.Headers['Content-Type']) | Select-Object -First 1)
    if ($contentType -like 'text/event-stream*') {
        # Take the first SSE event that carries the JSON-RPC response.
        foreach ($sseEvent in ($content -split "\r?\n\r?\n")) {
            $data = (($sseEvent -split "\r?\n") | Where-Object { $_ -like 'data:*' } | ForEach-Object { $_.Substring(5).TrimStart() }) -join "`n"
            if (-not $data) { continue }
            $parsed = ConvertFrom-McpJson -Json $data
            if ($parsed -is [System.Collections.IDictionary] -and $parsed['id'] -eq $Message['id']) { return $parsed }
        }
        throw 'No JSON-RPC response found in the SSE stream.'
    }
    ConvertFrom-McpJson -Json $content
}
