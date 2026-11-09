function Start-McpStdioServer {
    <#
    .SYNOPSIS
        Runs the MCP server over stdio: one JSON-RPC message per line on stdin/stdout.

    .DESCRIPTION
        stdout carries nothing but JSON-RPC messages, so all PowerShell host streams are
        silenced and diagnostics go to the log file only.

    .PARAMETER Context
        The server context created by New-McpServerContext.

    .EXAMPLE
        Start-McpStdioServer -Context (New-McpServerContext -KnowledgeBase $kb -Transport Stdio)

        Serves JSON-RPC messages on stdin/stdout until stdin is closed.
    #>
    [CmdletBinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal helper; it is started by Start-McpServer for AI clients and must not prompt.')]
    param(
        [Parameter(Mandatory)]
        [object] $Context
    )

    $WarningPreference = 'SilentlyContinue'
    $InformationPreference = 'SilentlyContinue'
    $VerbosePreference = 'SilentlyContinue'
    $DebugPreference = 'SilentlyContinue'
    $ProgressPreference = 'SilentlyContinue'

    $encoding = [System.Text.UTF8Encoding]::new($false)
    $reader = [System.IO.StreamReader]::new([Console]::OpenStandardInput(), $encoding, $false, 65536)
    $writer = [System.IO.StreamWriter]::new([Console]::OpenStandardOutput(), $encoding, 65536)
    $writer.AutoFlush = $true
    $writer.NewLine = "`n"

    Write-McpLog -Context $Context -Message ("stdio server started for knowledge base '{0}' (pid {1}, MCPPosh {2}, write access: {3})" -f $Context.KnowledgeBase.Name, $PID, $script:ModuleVersion, $Context.AllowWrite)
    try {
        $null = Update-McpServerIndex -Context $Context -Force
        while ($true) {
            $line = $reader.ReadLine()
            if ($null -eq $line) { break }
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            try {
                $response = Invoke-McpMessage -Context $Context -Json $line
            }
            catch {
                Write-McpLog -Context $Context -Level ERROR -Message "Unhandled error: $($_.Exception.Message)"
                $response = ConvertTo-McpJson -Compress -InputObject (New-McpErrorResponse -Id $null -Code -32603 -Message 'Internal error')
            }
            if ($null -ne $response) {
                $writer.WriteLine($response)
            }
        }
    }
    finally {
        Write-McpLog -Context $Context -Message 'stdio server stopped (stdin closed)'
        $writer.Dispose()
        $reader.Dispose()
    }
}
