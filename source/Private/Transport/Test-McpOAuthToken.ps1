function Test-McpOAuthToken {
    <#
    .SYNOPSIS
        Checks an OAuth access token (JWT) from the Authorization header against the configured issuer.

    .DESCRIPTION
        Checks the Bearer token of the Authorization header as a JSON Web Token: the signature (RS256) with the issuer's
        signing key (Get-McpOAuthSigningKey), the issuer (exact match), the audience, the expiry and not-before times
        (five minutes clock skew allowed) and the required scope in the scp or scope claim; without a configured scope
        the token must still carry a scp, scope or roles claim, so ID tokens are rejected. Malformed
        tokens return $false; errors while downloading the signing keys are thrown to the caller.

    .PARAMETER AuthorizationHeader
        Value of the Authorization header of the request, for example Bearer <token>.

    .PARAMETER OAuth
        Hashtable with Issuer, Audience (accepted aud values) and optionally Scope.

    .EXAMPLE
        Test-McpOAuthToken -AuthorizationHeader "Bearer $token" -OAuth @{ Issuer = 'https://login.microsoftonline.com/<tenant>/v2.0'; Audience = 'api://psmcpkb' }

        Returns $true when the token is valid for the issuer and the audience.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()]
        [string] $AuthorizationHeader,

        [Parameter(Mandatory)]
        [hashtable] $OAuth
    )

    if ($AuthorizationHeader -notmatch '^\s*Bearer\s+([A-Za-z0-9_-]+)\.([A-Za-z0-9_-]+)\.([A-Za-z0-9_-]+)\s*$') { return $false }
    $encodedHeader, $encodedPayload, $encodedSignature = $Matches[1], $Matches[2], $Matches[3]
    $decode = {
        param([string] $Value)
        $Value = $Value.Replace('-', '+').Replace('_', '/')
        $Value += '=' * ((4 - $Value.Length % 4) % 4)
        [System.Convert]::FromBase64String($Value)
    }

    try {
        $header = [System.Text.Encoding]::UTF8.GetString((& $decode $encodedHeader)) | ConvertFrom-Json -AsHashtable
        $claims = [System.Text.Encoding]::UTF8.GetString((& $decode $encodedPayload)) | ConvertFrom-Json -AsHashtable
        $signature = & $decode $encodedSignature
    }
    catch {
        return $false
    }
    if ($header -isnot [hashtable] -or $claims -isnot [hashtable]) { return $false }
    # Only RS256: "none" and HMAC algorithms would let anyone who knows the public key forge tokens.
    # shortcut: RS256 only (Entra ID, Auth0, Keycloak and Okta default); add ES256 when an identity provider needs it.
    if ($header['alg'] -cne 'RS256') { return $false }

    $jwk = Get-McpOAuthSigningKey -Issuer $OAuth.Issuer -KeyId ([string]$header['kid'])
    if (-not $jwk) { return $false }
    try {
        $rsa = [System.Security.Cryptography.RSA]::Create()
        try {
            $rsa.ImportParameters([System.Security.Cryptography.RSAParameters]@{ Modulus = (& $decode $jwk.n); Exponent = (& $decode $jwk.e) })
            $signed = [System.Text.Encoding]::ASCII.GetBytes("$encodedHeader.$encodedPayload")
            if (-not $rsa.VerifyData($signed, $signature, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)) { return $false }
        }
        finally {
            $rsa.Dispose()
        }
    }
    catch {
        return $false
    }

    if ($claims['iss'] -cne $OAuth.Issuer) { return $false }
    if (-not (@($claims['aud']) | Where-Object { $OAuth.Audience -contains $_ })) { return $false }
    $now = [System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $skew = 300
    if ($claims['exp'] -isnot [long] -and $claims['exp'] -isnot [int] -and $claims['exp'] -isnot [double]) { return $false }
    if ($now -ge $claims['exp'] + $skew) { return $false }
    if ($null -ne $claims['nbf'] -and $now -lt $claims['nbf'] - $skew) { return $false }

    if ($OAuth.Scope) {
        $granted = @("$($claims['scp']) $($claims['scope'])" -split ' ' | Where-Object { $_ })
        # Entra ID puts the short name (access_as_user) into scp, while clients request api://<app>/access_as_user.
        $shortName = ($OAuth.Scope -split '/')[-1]
        if ($granted -cnotcontains $OAuth.Scope -and $granted -cnotcontains $shortName) { return $false }
    }
    # ID tokens carry the client ID as audience too, but no scope or app roles; they prove a sign-in, not API access.
    elseif (-not ($claims['scp'] -or $claims['scope'] -or $claims['roles'])) { return $false }
    $true
}
