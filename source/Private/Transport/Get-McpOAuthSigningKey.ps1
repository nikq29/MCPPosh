function Get-McpOAuthSigningKey {
    <#
    .SYNOPSIS
        Returns the RSA signing key (JWK) of an OAuth issuer for a key id, or $null.

    .DESCRIPTION
        Reads the OpenID configuration of the issuer ({issuer}/.well-known/openid-configuration), downloads the key set
        from its jwks_uri and caches it per issuer. When the requested key id is not in the cache (the issuer rotated
        its keys), the key set is downloaded again, but at most once per minute, so tokens with made-up key ids cannot
        make the server flood the identity provider. Download errors are thrown to the caller.

    .PARAMETER Issuer
        The issuer URL, for example https://login.microsoftonline.com/<tenant>/v2.0.

    .PARAMETER KeyId
        The kid from the token header. Empty selects the first RSA signing key.

    .EXAMPLE
        Get-McpOAuthSigningKey -Issuer 'https://login.microsoftonline.com/contoso.onmicrosoft.com/v2.0' -KeyId 'abc'

        Returns the JWK with the key id 'abc' (properties kty, kid, n, e) or $null.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [string] $Issuer,

        [AllowEmptyString()]
        [string] $KeyId
    )

    if (-not $script:McpOAuthKeyCache) { $script:McpOAuthKeyCache = @{} }
    $find = {
        param($Keys, $Id)
        $Keys | Where-Object { $_.kty -eq 'RSA' -and (-not $_.use -or $_.use -eq 'sig') -and (-not $Id -or $_.kid -ceq $Id) } |
            Select-Object -First 1
    }

    $cached = $script:McpOAuthKeyCache[$Issuer]
    if ($cached) {
        $key = & $find $cached.Keys $KeyId
        if ($key -or [datetime]::UtcNow -lt $cached.FetchedAt.AddMinutes(1)) { return $key }
    }

    # Record the attempt before downloading: a failing identity provider is then also asked at most once per minute.
    $script:McpOAuthKeyCache[$Issuer] = @{ Keys = @(if ($cached) { $cached.Keys }); FetchedAt = [datetime]::UtcNow }
    $configuration = Invoke-RestMethod -Uri ($Issuer.TrimEnd('/') + '/.well-known/openid-configuration') -TimeoutSec 10 -ErrorAction Stop
    $jwks = Invoke-RestMethod -Uri $configuration.jwks_uri -TimeoutSec 10 -ErrorAction Stop
    $script:McpOAuthKeyCache[$Issuer].Keys = @($jwks.keys)
    & $find $script:McpOAuthKeyCache[$Issuer].Keys $KeyId
}
