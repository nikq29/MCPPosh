function Stop-McpStdioClient {
    [CmdletBinding()]
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
