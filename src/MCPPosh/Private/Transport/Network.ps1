function Test-McpLoopbackAddress {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $Address
    )

    $Address.Trim('[', ']') -in 'localhost', '127.0.0.1', '::1'
}

function Test-McpPortAvailable {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [int] $Port
    )

    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
    try {
        $listener.Start()
        return $true
    }
    catch {
        return $false
    }
    finally {
        try { $listener.Stop() } catch { $null = $_ }
    }
}

function Get-McpFreePort {
    [CmdletBinding()]
    [OutputType([int])]
    param()

    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    try {
        ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
    }
    finally {
        $listener.Stop()
    }
}

function Get-McpPwshPath {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $name = if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' }
    $candidate = Join-Path -Path $PSHOME -ChildPath $name
    if (Test-Path -LiteralPath $candidate) { return $candidate }
    $command = Get-Command -Name 'pwsh' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command.Source }
    throw 'Could not find pwsh (PowerShell 7). Make sure it is installed and on the PATH.'
}

function Test-McpApiKey {
    <#
    .SYNOPSIS
        Checks the Authorization (Bearer) or X-API-Key header against the configured keys
        using a constant-time comparison.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()]
        [string] $AuthorizationHeader,

        [AllowNull()]
        [string] $ApiKeyHeader,

        [Parameter(Mandatory)]
        [string[]] $ApiKeys
    )

    $presented = $null
    if ($AuthorizationHeader -and $AuthorizationHeader -match '^\s*Bearer\s+(.+?)\s*$') {
        $presented = $Matches[1]
    }
    elseif ($ApiKeyHeader) {
        $presented = $ApiKeyHeader.Trim()
    }
    if (-not $presented) { return $false }

    $presentedBytes = [System.Text.Encoding]::UTF8.GetBytes($presented)
    $valid = $false
    foreach ($key in $ApiKeys) {
        $keyBytes = [System.Text.Encoding]::UTF8.GetBytes($key)
        if ([System.Security.Cryptography.CryptographicOperations]::FixedTimeEquals($presentedBytes, $keyBytes)) {
            $valid = $true
        }
    }
    $valid
}
