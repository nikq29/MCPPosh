function Get-McpFreePort {
    <#
    .SYNOPSIS
        Returns a free TCP port on the loopback interface.

    .DESCRIPTION
        Asks the operating system for a free TCP port by binding a listener to port 0 on the loopback interface and returns the assigned port number.

    .EXAMPLE
        Start-McpServer -KnowledgeBase Contoso -Port (Get-McpFreePort)

        Starts a server on a free port. Get-McpFreePort returns for example 49731.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param()

    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    try {
        ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
    }
    finally {
        $listener.Stop()
    }
}
