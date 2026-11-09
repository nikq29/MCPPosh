function Start-McpStdioClient {
    <#
    .SYNOPSIS
        Starts a stdio MCP server process for the given knowledge base and returns a client handle.
    #>
    [CmdletBinding()]
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
