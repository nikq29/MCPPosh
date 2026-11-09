function Test-McpServerProcess {
    <#
    .SYNOPSIS
        True when the process exists and is the same process that wrote the state file
        (guards against PID reuse).
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
