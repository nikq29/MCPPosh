function Get-McpProcessStartTime {
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
