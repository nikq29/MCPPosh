function New-McpServerContext {
    <#
    .SYNOPSIS
        Creates the state object shared by the protocol handlers and the transports.
    #>
    [CmdletBinding()]
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
