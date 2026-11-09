function Test-McpServerProcess {
    <#
    .SYNOPSIS
        True when the process exists and is the same process that wrote the state file
        (guards against PID reuse).

    .DESCRIPTION
        Returns $true when a process with the id exists and, when a start time is given, started at that time. This prevents stopping an unrelated process that reused the process id of a stopped server.

    .PARAMETER ProcessId
        Process id recorded in the server state file.

    .PARAMETER ProcessStartTime
        Process start time recorded in the server state file, as an ISO 8601 string.

    .EXAMPLE
        Test-McpServerProcess -ProcessId $state.pid -ProcessStartTime $state.processStartTime

        Returns $true when the recorded server process is still running.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [int] $ProcessId,

        [string] $ProcessStartTime
    )

    $current = Get-McpProcessStartTime -ProcessId $ProcessId
    if (-not $current) { return $false }
    if (-not $ProcessStartTime) { return $true }
    try {
        $expected = [datetime]::Parse($ProcessStartTime, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
        $actual = [datetime]::Parse($current, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
        return [Math]::Abs(($expected - $actual).TotalSeconds) -lt 2
    }
    catch {
        return $true
    }
}
