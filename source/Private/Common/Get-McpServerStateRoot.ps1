function Get-McpServerStateRoot {
    <#
    .SYNOPSIS
        Returns the folder with the state files of local HTTP servers.

    .DESCRIPTION
        Returns the servers folder below the MCPPosh data directory, where running HTTP servers store their process id, port and settings, and creates it when needed.

    .EXAMPLE
        Get-McpServerStateRoot

        Returns for example /home/user/.mcpposh/servers.
    #>
    [CmdletBinding()]
    param()

    $path = Join-Path -Path (Get-McpHomePath) -ChildPath 'servers'
    if (-not [System.IO.Directory]::Exists($path)) {
        $null = [System.IO.Directory]::CreateDirectory($path)
    }
    $path
}
