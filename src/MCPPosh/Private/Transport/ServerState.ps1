function Get-McpServerStateFile {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $KnowledgeBaseName,

        [Parameter(Mandatory)]
        [int] $Port
    )

    Join-Path -Path (Get-McpServerStateRoot) -ChildPath ('{0}-{1}.json' -f (ConvertTo-McpSlug -Text $KnowledgeBaseName), $Port)
}

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
