function Start-McpStdioClient {
    <#
    .SYNOPSIS
        Starts a stdio MCP server process for the given knowledge base and returns a client handle.

    .DESCRIPTION
        Starts a PowerShell process that runs Start-McpServer -Transport Stdio for a knowledge base, exactly as an AI client does, with redirected stdin, stdout and stderr, and returns a handle for Invoke-McpStdioRpc.

    .PARAMETER KbPath
        Directory of the knowledge base the stdio server provides.

    .PARAMETER AllowWrite
        Starts the server with write access so the add_note tool is available.

    .EXAMPLE
        $client = Start-McpStdioClient -KbPath $kb.Path

        Starts a stdio server process for the knowledge base.
    #>
    [CmdletBinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal helper used by Test-McpServer to start a temporary test process.')]
    param(
        [Parameter(Mandatory)]
        [string] $KbPath,

        [switch] $AllowWrite
    )

    $quotedManifest = "'" + $script:ModuleManifestPath.Replace("'", "''") + "'"
    $quotedKb = "'" + $KbPath.Replace("'", "''") + "'"
    $command = "Import-Module -Name $quotedManifest; Start-McpServer -KnowledgeBase $quotedKb -Transport Stdio" + $(if ($AllowWrite) { ' -AllowWrite' } else { '' })

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = Get-McpPwshPath
    foreach ($argument in '-NoProfile', '-NonInteractive', '-Command', $command) { $startInfo.ArgumentList.Add($argument) }
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true
    $startInfo.StandardOutputEncoding = $script:Utf8NoBom
    $startInfo.StandardErrorEncoding = $script:Utf8NoBom
    if ($startInfo.PSObject.Properties['StandardInputEncoding']) { $startInfo.StandardInputEncoding = $script:Utf8NoBom }

    $process = [System.Diagnostics.Process]::Start($startInfo)
    $errorTask = $process.StandardError.ReadToEndAsync()
    [pscustomobject]@{
        Process   = $process
        ErrorTask = $errorTask
    }
}
