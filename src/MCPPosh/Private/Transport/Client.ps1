function Invoke-McpHttpRpc {
    <#
    .SYNOPSIS
        Minimal MCP Streamable HTTP client: sends one JSON-RPC message and returns the parsed
        response (JSON or SSE). Returns $null for notifications.
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
        foreach ($event in ($content -split "\r?\n\r?\n")) {
            $data = (($event -split "\r?\n") | Where-Object { $_ -like 'data:*' } | ForEach-Object { $_.Substring(5).TrimStart() }) -join "`n"
            if (-not $data) { continue }
            $parsed = ConvertFrom-McpJson -Json $data
            if ($parsed -is [System.Collections.IDictionary] -and $parsed['id'] -eq $Message['id']) { return $parsed }
        }
        throw 'No JSON-RPC response found in the SSE stream.'
    }
    ConvertFrom-McpJson -Json $content
}

function Start-McpStdioClient {
    <#
    .SYNOPSIS
        Starts a stdio MCP server process for the given knowledge base and returns a client handle.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $KbPath,

        [switch] $AllowWrite
    )

    $quotedManifest = "'" + $script:ModuleManifestPath.Replace("'", "''") + "'"
    $quotedKb = "'" + $KbPath.Replace("'", "''") + "'"
    $command = "Import-Module -Name $quotedManifest; Start-McpServer -KnowledgeBase $quotedKb -Transport Stdio" + $(if ($AllowWrite) { ' -AllowWrite' } else { '' })

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = Get-McpPwshPath
    foreach ($argument in '-NoProfile', '-NonInteractive', '-Command', $command) { $startInfo.ArgumentList.Add($argument) }
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true
    $startInfo.StandardOutputEncoding = $script:Utf8NoBom
    $startInfo.StandardErrorEncoding = $script:Utf8NoBom
    if ($startInfo.PSObject.Properties['StandardInputEncoding']) { $startInfo.StandardInputEncoding = $script:Utf8NoBom }

    $process = [System.Diagnostics.Process]::Start($startInfo)
    $errorTask = $process.StandardError.ReadToEndAsync()
    [pscustomobject]@{
        Process   = $process
        ErrorTask = $errorTask
    }
}

function Invoke-McpStdioRpc {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Client,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Message,

        [int] $TimeoutSeconds = 30
    )

    $Client.Process.StandardInput.WriteLine((ConvertTo-McpJson -Compress -InputObject $Message))
    $Client.Process.StandardInput.Flush()
    if (-not $Message.Contains('id')) { return $null }

    $deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ($true) {
        $remaining = [int]($deadline - [datetime]::UtcNow).TotalMilliseconds
        if ($remaining -le 0) { throw "Timed out after $TimeoutSeconds seconds waiting for a response to '$($Message['method'])'." }
        $readTask = $Client.Process.StandardOutput.ReadLineAsync()
        if (-not $readTask.Wait($remaining)) { throw "Timed out after $TimeoutSeconds seconds waiting for a response to '$($Message['method'])'." }
        $line = $readTask.Result
        if ($null -eq $line) {
            $stderr = if ($Client.ErrorTask.Wait(2000)) { $Client.ErrorTask.Result } else { '' }
            throw "The stdio server exited unexpectedly. $stderr"
        }
        try {
            $parsed = ConvertFrom-McpJson -Json $line
        }
        catch {
            throw "The stdio server wrote non-JSON output to stdout: $line"
        }
        if ($parsed -is [System.Collections.IDictionary] -and $parsed['id'] -eq $Message['id']) { return $parsed }
    }
}

function Stop-McpStdioClient {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Client
    )

    try {
        $Client.Process.StandardInput.Close()
        if (-not $Client.Process.WaitForExit(5000)) { $Client.Process.Kill($true) }
    }
    catch {
        $null = $_
    }
    finally {
        $Client.Process.Dispose()
    }
}
