function Get-McpServerState {
    <#
    .SYNOPSIS
        Reads the state files of locally started HTTP servers and adds a Status (Running/Stale).
    #>
    [CmdletBinding()]
    param()

    $root = Get-McpServerStateRoot
    foreach ($file in (Get-ChildItem -LiteralPath $root -Filter '*.json' -File -ErrorAction SilentlyContinue)) {
        try {
            $state = Read-McpJsonFile -Path $file.FullName
        }
        catch {
            continue
        }
        if ($null -eq $state) { continue }
        $alive = Test-McpServerProcess -ProcessId ([int]$state.pid) -ProcessStartTime ([string]$state.processStartTime)
        $state['Status'] = if ($alive) { 'Running' } else { 'Stale' }
        $state['StateFile'] = $file.FullName
        [pscustomobject]$state
    }
}
