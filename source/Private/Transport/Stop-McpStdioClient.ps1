function Stop-McpStdioClient {
    <#
    .SYNOPSIS
        Stops a stdio MCP server process started for a test.

    .DESCRIPTION
        Closes stdin of a stdio server process started with Start-McpStdioClient so that it exits, kills it when it does not exit within five seconds and releases the process handle.

    .PARAMETER Client
        The client handle returned by Start-McpStdioClient.

    .EXAMPLE
        Stop-McpStdioClient -Client $client

        Stops the stdio server process.
    #>
    [CmdletBinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal helper used by Test-McpServer to stop its own temporary test process.')]
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
