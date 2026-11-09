function New-McpServerContext {
    <#
    .SYNOPSIS
        Creates the state object shared by the protocol handlers and the transports.

    .DESCRIPTION
        Creates the context object shared by the protocol handlers and the transports: the knowledge base, the transport, write access, log settings, the negotiated protocol version, statistics and the cached search index.

    .PARAMETER KnowledgeBase
        The resolved knowledge base (see Resolve-McpKnowledgeBase) that the server provides.

    .PARAMETER Transport
        The transport the server runs on: Stdio or Http. Determines the default log file name.

    .PARAMETER AllowWrite
        Enables the add_note tool so AI agents can store notes in the knowledge base.

    .PARAMETER LogPath
        Path of the log file. Defaults to logs/server-stdio.log or logs/server-http.log in the knowledge base.

    .PARAMETER EchoLog
        Also writes log lines to the console, for foreground HTTP servers and containers.

    .EXAMPLE
        New-McpServerContext -KnowledgeBase (Resolve-McpKnowledgeBase -KnowledgeBase Contoso) -Transport Http -AllowWrite

        Creates a context for an HTTP server with write access.
    #>
    [CmdletBinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an in-memory context object only; no system state is changed.')]
    param(
        [Parameter(Mandatory)]
        [object] $KnowledgeBase,

        [ValidateSet('Stdio', 'Http')]
        [string] $Transport = 'Stdio',

        [switch] $AllowWrite,

        [string] $LogPath,

        [switch] $EchoLog
    )

    if (-not $LogPath) {
        $logName = if ($Transport -eq 'Stdio') { 'server-stdio.log' } else { 'server-http.log' }
        $LogPath = Join-Path -Path $KnowledgeBase.Path -ChildPath "logs/$logName"
    }

    [pscustomobject]@{
        KnowledgeBase   = $KnowledgeBase
        Transport       = $Transport
        AllowWrite      = [bool]$AllowWrite
        LogPath         = $LogPath
        EchoLog         = [bool]$EchoLog
        StartedAt       = [datetime]::UtcNow
        LastIndexCheck  = [datetime]::MinValue
        Index           = $null
        ProtocolVersion = $script:McpSupportedProtocolVersions[0]
        ClientInfo      = $null
        RequestCount    = 0L
    }
}
