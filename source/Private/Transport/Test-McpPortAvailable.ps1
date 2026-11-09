function Test-McpPortAvailable {
    <#
    .SYNOPSIS
        Tests whether a TCP port is free on the loopback interface.

    .DESCRIPTION
        Tries to bind a TCP listener to the port on the loopback interface and returns $true when that succeeds, so a server can be started on it.

    .PARAMETER Port
        The TCP port number to test, for example 5050.

    .EXAMPLE
        Test-McpPortAvailable -Port 5050

        Returns $true when nothing listens on port 5050.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [int] $Port
    )

    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
    try {
        $listener.Start()
        return $true
    }
    catch {
        return $false
    }
    finally {
        try { $listener.Stop() } catch { $null = $_ }
    }
}
