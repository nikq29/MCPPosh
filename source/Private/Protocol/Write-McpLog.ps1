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
