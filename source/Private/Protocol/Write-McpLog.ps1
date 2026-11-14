function Write-McpLog {
    <#
    .SYNOPSIS
        Appends a line to the server log. Never writes to stdout (reserved for stdio JSON-RPC).

    .DESCRIPTION
        Appends a timestamped line to the log file of the server and, for foreground HTTP servers, to the console. It never writes to stdout of a stdio server, where only JSON-RPC messages are allowed, and logging errors are ignored.

    .PARAMETER Context
        The server context created by New-McpServerContext; it defines the log file and console echo.

    .PARAMETER Message
        The text of the log entry; it is written after the timestamp and level.

    .PARAMETER Level
        Severity of the message: INFO, WARN, ERROR or DEBUG.

    .EXAMPLE
        Write-McpLog -Context $context -Level WARN -Message 'Rejected request from origin evil.example.com'

        Appends a warning to the server log.
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

    # Messages contain client input (search queries, note titles): escape line breaks and other control
    # characters so a client cannot forge additional log lines.
    $safeMessage = [regex]::Replace($Message, '[\x00-\x1F\x7F\u0085\u2028\u2029]', {
            param($m)
            switch ($m.Value) {
                "`r" { '\r' }
                "`n" { '\n' }
                "`t" { '\t' }
                default { '\u{0:x4}' -f [int][char]$m.Value }
            }
        })
    $line = '{0} [{1}] {2}' -f [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ'), $Level, $safeMessage
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
