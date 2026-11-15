function Start-McpServer {
    <#
    .SYNOPSIS
        Starts an MCP server that provides a knowledge base to AI agents.

    .DESCRIPTION
        Transport 'Stdio' runs the server in the current process and talks JSON-RPC over
        stdin/stdout. This is what AI clients such as Claude Desktop, Claude Code, VS Code or
        Cursor start themselves; see Get-McpClientConfig for ready-to-use configuration.

        Transport 'Http' (default) serves the Streamable HTTP transport on http://<address>:<port>/mcp.
        Without -Foreground the server is started as a hidden background PowerShell process that
        you manage with Get-McpServer, Stop-McpServer, Restart-McpServer and Get-McpServerLog.
        Use -Foreground for containers (e.g. Azure Container Apps) or debugging.

        Documents added or changed while the server runs are picked up automatically.

    .PARAMETER KnowledgeBase
        Name or directory path of the knowledge base to serve.

    .PARAMETER Transport
        Stdio runs the server over stdin/stdout for AI clients; Http serves the Streamable HTTP transport (default).

    .PARAMETER Port
        TCP port for the HTTP transport.

    .PARAMETER ListenAddress
        Address to listen on. 'localhost' (default) only accepts local connections. Use '*' to
        listen on all interfaces (requires -ApiKey, -OAuthIssuer or -AllowAnonymous; on Windows also admin
        rights or a URL ACL: netsh http add urlacl url=http://+:<port>/ user=<user>).

    .PARAMETER ApiKey
        One or more API keys. Clients must send 'Authorization: Bearer <key>' or 'X-API-Key: <key>'.
        Defaults to the comma-separated keys in $env:PSMCPKB_API_KEY.

    .PARAMETER OAuthIssuer
        Issuer URL of an OpenID Connect identity provider, e.g. https://login.microsoftonline.com/<tenant>/v2.0
        (https; http only for localhost). The server then also accepts OAuth access tokens (JWT, RS256) from this issuer as 'Authorization: Bearer <token>'
        and publishes /.well-known/oauth-protected-resource so MCP clients can sign in. API keys keep working.
        Defaults to $env:PSMCPKB_OAUTH_ISSUER.

    .PARAMETER OAuthAudience
        Accepted audiences (aud claim) of the access tokens, e.g. the client ID (Microsoft Entra ID v2 tokens) or the
        API identifier configured at the identity provider. Required with -OAuthIssuer. Defaults to the comma-separated values in $env:PSMCPKB_OAUTH_AUDIENCE.

    .PARAMETER OAuthScope
        Scope the access tokens must contain (scp or scope claim), e.g. api://<client-id>/access_as_user. It is also
        advertised to MCP clients. Defaults to $env:PSMCPKB_OAUTH_SCOPE.

    .PARAMETER AllowedOrigin
        Browser origins allowed to call the server (CORS), e.g. https://my-app.example.com.

    .PARAMETER AllowWrite
        Adds the add_note tool so the AI agent can store new knowledge.

    .PARAMETER AllowAnonymous
        Allows listening on a non-loopback address without an API key or OAuth (e.g. behind a gateway
        that authenticates requests).

    .PARAMETER Foreground
        Run the HTTP server in the current process (blocks until Ctrl+C).

    .PARAMETER StartTimeoutSeconds
        Seconds to wait for a background HTTP server to answer its health check before the start is considered failed.

    .PARAMETER BackgroundChild
        Internal switch used by the background process that Start-McpServer starts itself. Do not use it directly.

    .EXAMPLE
        Start-McpServer -KnowledgeBase Contoso

        Starts a hidden background HTTP server on http://localhost:5050/mcp and returns its status.

    .EXAMPLE
        Start-McpServer -KnowledgeBase Contoso -Transport Stdio

        Runs the server over stdin/stdout. AI clients use this command in their configuration; see Get-McpClientConfig.

    .EXAMPLE
        Start-McpServer -KnowledgeBase Contoso -Port 8080 -ListenAddress '*' -ApiKey $key -Foreground

        Runs an HTTP server reachable from the network in the current console, for example in a container. Clients must send the API key.

    .EXAMPLE
        Start-McpServer -KnowledgeBase Contoso -Port 8080 -ListenAddress '*' -OAuthIssuer "https://login.microsoftonline.com/$tenantId/v2.0" -OAuthAudience $clientId -OAuthScope "api://$clientId/access_as_user" -Foreground

        Runs an HTTP server that accepts Microsoft Entra ID access tokens; MCP clients sign in with OAuth.

    .EXAMPLE
        Start-McpServer -KnowledgeBase Contoso -Port 5051 -ApiKey $key -AllowWrite

        Starts a background server that additionally offers the add_note tool, so agents can store new knowledge.

    .INPUTS
        None. You cannot pipe objects to this cmdlet.

    .OUTPUTS
        None for -Transport Stdio and for -Foreground (the server runs until it is stopped). PSMcpKnowledgeBase.Server: KnowledgeBase, Transport, Status (Running or Stopped), Url, Port, ListenAddress, ProcessId, StartedAt, Uptime, AuthRequired, AllowWrite, AllowAnonymous, AllowedOrigins, LogFile, KnowledgeBasePath and Version. for background HTTP servers.

    .LINK
        https://github.com/nikq29/PSMcpKnowledgeBase/blob/main/docs/en-US/Start-McpServer.md

    .LINK
        Stop-McpServer

    .LINK
        Get-McpServer

    .LINK
        Test-McpServer

    .LINK
        Get-McpClientConfig
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('PSMcpKnowledgeBase.Server')]
    param(
        [Parameter(Position = 0)]
        [string] $KnowledgeBase = 'Default',

        [ValidateSet('Stdio', 'Http')]
        [string] $Transport = 'Http',

        [ValidateRange(1, 65535)]
        [int] $Port = 5050,

        [string] $ListenAddress = 'localhost',

        [string[]] $ApiKey,

        [string] $OAuthIssuer,

        [string[]] $OAuthAudience,

        [string] $OAuthScope,

        [string[]] $AllowedOrigin,

        [switch] $AllowWrite,

        [switch] $AllowAnonymous,

        [switch] $Foreground,

        [ValidateRange(1, 300)]
        [int] $StartTimeoutSeconds = 30,

        # Internal: set for the background process started by Start-McpServer itself.
        [Parameter(DontShow)]
        [switch] $BackgroundChild
    )

    $kb = Resolve-McpKnowledgeBase -KnowledgeBase $KnowledgeBase -CreateIfMissing:($KnowledgeBase -eq 'Default')

    if ($Transport -eq 'Stdio') {
        $context = New-McpServerContext -KnowledgeBase $kb -Transport Stdio -AllowWrite:$AllowWrite
        Start-McpStdioServer -Context $context
        return
    }

    $keys = [string[]]@(@(if ($ApiKey) { $ApiKey } elseif ($env:PSMCPKB_API_KEY) { $env:PSMCPKB_API_KEY -split ',' }) |
            ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if (-not $OAuthIssuer) { $OAuthIssuer = $env:PSMCPKB_OAUTH_ISSUER }
    if (-not $OAuthAudience -and $env:PSMCPKB_OAUTH_AUDIENCE) { $OAuthAudience = $env:PSMCPKB_OAUTH_AUDIENCE -split ',' }
    if (-not $OAuthScope) { $OAuthScope = $env:PSMCPKB_OAUTH_SCOPE }
    $oauth = $null
    if ($OAuthIssuer) {
        # The signing keys are downloaded from the issuer, so plain http (keys can be swapped on the way) only for localhost.
        if (-not [uri]::IsWellFormedUriString($OAuthIssuer, [System.UriKind]::Absolute) -or
            -not ($OAuthIssuer -match '^https://' -or ($OAuthIssuer -match '^http://' -and ([uri]$OAuthIssuer).IsLoopback))) {
            throw "-OAuthIssuer must be an https URL such as https://login.microsoftonline.com/<tenant>/v2.0 (http only for localhost), not '$OAuthIssuer'."
        }
        $audiences = [string[]]@($OAuthAudience | Where-Object { $_ } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        if ($audiences.Count -eq 0) {
            throw '-OAuthIssuer requires -OAuthAudience (or $env:PSMCPKB_OAUTH_AUDIENCE): the client ID or application ID URI the tokens are issued for.'
        }
        $oauth = @{ Issuer = $OAuthIssuer; Audience = $audiences; Scope = $OAuthScope }
    }

    $isLoopback = Test-McpLoopbackAddress -Address $ListenAddress
    if (-not $isLoopback -and $keys.Count -eq 0 -and -not $oauth -and -not $AllowAnonymous) {
        throw "Listening on '$ListenAddress' exposes the server to the network. Specify -ApiKey (or `$env:PSMCPKB_API_KEY), -OAuthIssuer, or -AllowAnonymous if a gateway authenticates requests."
    }

    if ($Foreground) {
        $logPath = Join-Path -Path $kb.Path -ChildPath "logs/server-$Port.log"
        $context = New-McpServerContext -KnowledgeBase $kb -Transport Http -AllowWrite:$AllowWrite -LogPath $logPath -EchoLog:(-not $BackgroundChild)
        Start-McpHttpServer -Context $context -Port $Port -ListenAddress $ListenAddress -ApiKeys $keys -AllowedOrigins $AllowedOrigin -AllowAnonymous:$AllowAnonymous -OAuth $oauth
        return
    }

    # Background process
    $existing = Get-McpServerState | Where-Object { [int]$_.port -eq $Port -and $_.Status -eq 'Running' }
    if ($existing) {
        throw "A PSMcpKnowledgeBase server is already running on port $Port (knowledge base '$($existing.knowledgeBase)', pid $($existing.pid)). Stop it with: Stop-McpServer -Port $Port"
    }
    if (-not (Test-McpPortAvailable -Port $Port)) {
        throw "Port $Port is already in use. Choose another port with -Port."
    }
    if (-not $PSCmdlet.ShouldProcess("$($kb.Name) on port $Port", 'Start MCP server in the background')) { return }

    $logDirectory = Join-Path -Path $kb.Path -ChildPath 'logs'
    $null = New-Item -ItemType Directory -Path $logDirectory -Force
    $stdoutLog = Join-Path -Path $logDirectory -ChildPath "server-$Port.stdout.log"
    $stderrLog = Join-Path -Path $logDirectory -ChildPath "server-$Port.stderr.log"

    # PowerShell also ends single-quoted strings at the curly quotes U+2018-U+201B (macOS types U+2019 in folder
    # names); this escapes all of them.
    $quote = { param($Value) "'" + [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent([string]$Value) + "'" }
    $command = [System.Text.StringBuilder]::new()
    $null = $command.Append("`$ErrorActionPreference = 'Stop'; `$ProgressPreference = 'SilentlyContinue'; ")
    $null = $command.Append("Import-Module -Name $(& $quote $script:ModuleManifestPath) -Force; ")
    $null = $command.Append("Start-McpServer -KnowledgeBase $(& $quote $kb.Path) -Transport Http -Port $Port -ListenAddress $(& $quote $ListenAddress) -Foreground -BackgroundChild")
    if ($AllowWrite) { $null = $command.Append(' -AllowWrite') }
    if ($AllowAnonymous) { $null = $command.Append(' -AllowAnonymous') }
    if ($oauth) {
        $null = $command.Append(" -OAuthIssuer $(& $quote $oauth.Issuer) -OAuthAudience " + (($oauth.Audience | ForEach-Object { & $quote $_ }) -join ','))
        if ($oauth.Scope) { $null = $command.Append(" -OAuthScope $(& $quote $oauth.Scope)") }
    }
    if ($AllowedOrigin) { $null = $command.Append(' -AllowedOrigin ' + (($AllowedOrigin | ForEach-Object { & $quote $_ }) -join ',')) }
    $encoded = [System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($command.ToString()))

    $pwsh = Get-McpPwshPath
    $arguments = @('-NoProfile', '-NonInteractive', '-EncodedCommand', $encoded)
    $startArgs = @{
        FilePath               = $pwsh
        ArgumentList           = $arguments
        RedirectStandardOutput = $stdoutLog
        RedirectStandardError  = $stderrLog
        PassThru               = $true
    }
    if ($IsWindows) {
        $startArgs['WindowStyle'] = 'Hidden'
    }
    elseif ($IsLinux -and (Test-Path -LiteralPath '/usr/bin/setsid')) {
        # Detach from the terminal session so closing the terminal does not stop the server.
        $startArgs['FilePath'] = '/usr/bin/setsid'
        $startArgs['ArgumentList'] = @($pwsh) + $arguments
    }

    # API keys are handed over via the environment, never on the command line.
    $previousKey = $env:PSMCPKB_API_KEY
    try {
        $env:PSMCPKB_API_KEY = if ($keys.Count -gt 0) { $keys -join ',' } else { $null }
        $process = Start-Process @startArgs
    }
    finally {
        $env:PSMCPKB_API_KEY = $previousKey
    }

    $healthHost = if ($isLoopback -or $ListenAddress -in '*', '+', '0.0.0.0', '::') { 'localhost' } else { $ListenAddress }
    $healthUrl = "http://${healthHost}:$Port/health"
    $deadline = [datetime]::UtcNow.AddSeconds($StartTimeoutSeconds)
    while ([datetime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 250
        $state = Get-McpServerState | Where-Object { [int]$_.port -eq $Port -and $_.Status -eq 'Running' }
        if ($state) {
            try {
                $null = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 2 -ErrorAction Stop
                return Get-McpServer -Port $Port
            }
            catch {
                $null = $_
            }
        }
        $process.Refresh()
        if ($process.HasExited) { break }
    }

    $details = @()
    foreach ($file in $stderrLog, $stdoutLog) {
        if (Test-Path -LiteralPath $file) { $details += Get-Content -LiteralPath $file -Tail 20 -ErrorAction SilentlyContinue }
    }
    if (-not $process.HasExited) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }
    throw ("The MCP server did not start within $StartTimeoutSeconds seconds." + $(if ($details) { "`n" + ($details -join "`n") } else { " See $stderrLog" }))
}
