function Invoke-McpKnowledgeBaseLock {
    <#
    .SYNOPSIS
        Runs a script block while holding an exclusive lock on a knowledge base.
    .DESCRIPTION
        The PowerShell session and a running server (add_note tool) may write to the same
        knowledge base concurrently. The lock serializes manifest updates across processes.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $KbPath,

        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock,

        [int] $TimeoutSeconds = 30
    )

    $mcpLockFile = [System.IO.Path]::Combine($KbPath, '.lock')
    $mcpLockWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $mcpLockStream = $null
    while ($null -eq $mcpLockStream) {
        try {
            $mcpLockStream = [System.IO.File]::Open($mcpLockFile, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        }
        catch [System.IO.IOException], [System.UnauthorizedAccessException] {
            if ($mcpLockWatch.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
                throw "Timed out after $TimeoutSeconds seconds waiting for the lock on knowledge base '$KbPath'."
            }
            Start-Sleep -Milliseconds 100
        }
    }
    try {
        & $ScriptBlock
    }
    finally {
        $mcpLockStream.Dispose()
    }
}
