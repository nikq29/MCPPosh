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
