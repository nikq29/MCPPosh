$script:McpSupportedProtocolVersions = @('2025-11-25', '2025-06-18', '2025-03-26', '2024-11-05')

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

function Write-McpLog {
    <#
    .SYNOPSIS
        Appends a line to the server log. Never writes to stdout (reserved for stdio JSON-RPC).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Context,

        [Parameter(Mandatory)]
        [string] $Message,

        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
        [string] $Level = 'INFO'
    )

    $line = '{0} [{1}] {2}' -f [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ'), $Level, $Message
    if ($Context.LogPath) {
        try {
            $directory = [System.IO.Path]::GetDirectoryName($Context.LogPath)
            if (-not [System.IO.Directory]::Exists($directory)) { $null = [System.IO.Directory]::CreateDirectory($directory) }
            [System.IO.File]::AppendAllText($Context.LogPath, $line + [Environment]::NewLine, $script:Utf8NoBom)
        }
        catch {
            # Logging must never break request handling.
            $null = $_
        }
    }
    if ($Context.EchoLog) {
        # Foreground HTTP servers (console, containers) also log to the console.
        [Console]::Out.WriteLine($line)
    }
}

function Update-McpServerIndex {
    <#
    .SYNOPSIS
        Reloads knowledge base metadata and the search index when the manifest changed.
        Checks the file system at most once per second.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Context,

        [switch] $Force
    )

    $now = [datetime]::UtcNow
    if (-not $Force -and $null -ne $Context.Index -and ($now - $Context.LastIndexCheck).TotalMilliseconds -lt 1000) {
        return $Context.Index
    }
    $Context.LastIndexCheck = $now

    $previousStamp = if ($Context.Index) { $Context.Index.Stamp } else { $null }
    $index = Get-McpSearchIndex -KbPath $Context.KnowledgeBase.Path -Force:$Force
    if ($index.Stamp -ne $previousStamp) {
        $meta = Read-McpJsonFile -Path (Join-Path -Path $Context.KnowledgeBase.Path -ChildPath 'knowledgebase.json')
        if ($meta) { $Context.KnowledgeBase.Description = [string]$meta.description }
        if ($previousStamp) {
            Write-McpLog -Context $Context -Message ("Knowledge base reloaded: revision {0}, {1} documents, {2} chunks" -f $index.Revision, $index.Documents.Count, $index.Chunks.Count)
        }
    }
    $Context.Index = $index
    $index
}

function New-McpRpcError {
    <#
    .SYNOPSIS
        Creates an exception carrying a JSON-RPC error code.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int] $Code,

        [Parameter(Mandatory)]
        [string] $Message,

        [object] $Data
    )

    $exception = [System.InvalidOperationException]::new($Message)
    $exception.Data['McpRpcCode'] = $Code
    if ($null -ne $Data) { $exception.Data['McpRpcData'] = $Data }
    $exception
}
