function Test-McpApiKey {
    <#
    .SYNOPSIS
        Checks the Authorization (Bearer) or X-API-Key header against the configured keys
        using a constant-time comparison.

    .DESCRIPTION
        Checks the API key presented in the Authorization header (Bearer scheme) or in the X-API-Key header against the configured keys. The comparison runs in constant time to avoid timing attacks.

    .PARAMETER AuthorizationHeader
        Value of the Authorization header of the request, for example Bearer <key>.

    .PARAMETER ApiKeyHeader
        Value of the X-API-Key header of the request.

    .PARAMETER ApiKeys
        The API keys accepted by the server.

    .EXAMPLE
        Test-McpApiKey -AuthorizationHeader 'Bearer secret-key' -ApiKeys 'secret-key', 'old-key'

        Returns $true.
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

    # Compare SHA-256 hashes: FixedTimeEquals returns early when the lengths differ, which would reveal the key
    # length; hashes always have the same length. Every key is checked, so the time does not show which one matched.
    $presentedHash = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($presented))
    $valid = $false
    foreach ($key in $ApiKeys) {
        $keyHash = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($key))
        if ([System.Security.Cryptography.CryptographicOperations]::FixedTimeEquals($presentedHash, $keyHash)) {
            $valid = $true
        }
    }
    $valid
}
