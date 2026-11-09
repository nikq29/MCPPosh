function Lock-McpKnowledgeBase {
    <#
    .SYNOPSIS
        Acquires an exclusive lock on a knowledge base.

    .DESCRIPTION
        Opens the .lock file of a knowledge base exclusively and returns the file stream. The PowerShell session and a running server (add_note tool) can write to the same knowledge base, so writers hold this lock while they update the manifest. Dispose the returned stream to release the lock.

    .PARAMETER KbPath
        Directory of the knowledge base to lock. The .lock file is created in this directory.

    .PARAMETER TimeoutSeconds
        Seconds to wait for another process to release the lock before an error is thrown.

    .EXAMPLE
        $kbLock = Lock-McpKnowledgeBase -KbPath $kb.Path
        try {
            # update manifest.json
        }
        finally {
            $kbLock.Dispose()
        }

        Holds the lock while the manifest is updated and always releases it.

    .OUTPUTS
        System.IO.FileStream
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileStream])]
    param(
        [Parameter(Mandatory)]
        [string] $KbPath,

        [ValidateRange(1, 3600)]
        [int] $TimeoutSeconds = 30
    )

    $lockFile = [System.IO.Path]::Combine($KbPath, '.lock')
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        try {
            return [System.IO.File]::Open($lockFile, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        }
        catch [System.IO.IOException], [System.UnauthorizedAccessException] {
            if ($watch.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
                throw "Timed out after $TimeoutSeconds seconds waiting for the lock on knowledge base '$KbPath'."
            }
            Start-Sleep -Milliseconds 100
        }
    }
}
