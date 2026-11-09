function Get-McpProcessStartTime {
    <#
    .SYNOPSIS
        Returns the start time of a process.

    .DESCRIPTION
        Returns the start time of a running process as an ISO 8601 UTC string, or $null when the process does not exist or has exited. Used to detect reused process ids.

    .PARAMETER ProcessId
        Id of the process whose start time is returned.

    .EXAMPLE
        Get-McpProcessStartTime -ProcessId $PID

        Returns the start time of the current PowerShell process.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int] $ProcessId
    )

    try {
        $process = [System.Diagnostics.Process]::GetProcessById($ProcessId)
        if ($process.HasExited) { return $null }
        $process.StartTime.ToUniversalTime().ToString('o')
    }
    catch {
        $null
    }
}
