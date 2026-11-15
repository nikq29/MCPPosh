BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/PSMcpKnowledgeBase.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'PSMcpKnowledgeBase'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Test-McpOAuthToken' {
    BeforeAll {
        $script:Issuer = 'https://login.example.com/tenant/v2.0'
        $script:OAuth = @{ Issuer = $script:Issuer; Audience = @('client-id', 'api://client-id'); Scope = $null }
        $script:Rsa = [System.Security.Cryptography.RSA]::Create(2048)
        $script:OtherRsa = [System.Security.Cryptography.RSA]::Create(2048)

        function ConvertTo-TestBase64Url([byte[]] $Bytes) { [Convert]::ToBase64String($Bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_') }
        function ConvertTo-TestSegment($Object) { ConvertTo-TestBase64Url ([System.Text.Encoding]::UTF8.GetBytes(($Object | ConvertTo-Json -Compress))) }

        $parameters = $script:Rsa.ExportParameters($false)
        $script:Jwk = [pscustomobject]@{ kty = 'RSA'; use = 'sig'; kid = 'key1'; n = (ConvertTo-TestBase64Url $parameters.Modulus); e = (ConvertTo-TestBase64Url $parameters.Exponent) }

        function New-TestToken {
            param([hashtable] $Claims = @{}, [hashtable] $Header = @{}, $Key = $script:Rsa)
            $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            $body = @{ iss = $script:Issuer; aud = 'client-id'; exp = $now + 3600; nbf = $now - 10; roles = @('Reader') }
            foreach ($entry in $Claims.GetEnumerator()) { $body[$entry.Key] = $entry.Value }
            $head = @{ alg = 'RS256'; typ = 'JWT'; kid = 'key1' }
            foreach ($entry in $Header.GetEnumerator()) { $head[$entry.Key] = $entry.Value }
            $unsigned = "$(ConvertTo-TestSegment $head).$(ConvertTo-TestSegment $body)"
            $signature = $Key.SignData([System.Text.Encoding]::ASCII.GetBytes($unsigned), [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
            "$unsigned.$(ConvertTo-TestBase64Url $signature)"
        }

        function Test-Token([string] $Token, [hashtable] $OAuth = $script:OAuth) {
            InModuleScope PSMcpKnowledgeBase -Parameters @{ Token = $Token; OAuth = $OAuth; Jwk = $script:Jwk } {
                param($Token, $OAuth, $Jwk)
                Mock Get-McpOAuthSigningKey { if ($KeyId -ceq 'key1') { $Jwk } }
                Test-McpOAuthToken -AuthorizationHeader "Bearer $Token" -OAuth $OAuth
            }
        }
    }

    AfterAll {
        $script:Rsa.Dispose()
        $script:OtherRsa.Dispose()
    }

    It 'accepts a valid token for each configured audience, also with an audience list' {
        Test-Token (New-TestToken) | Should -BeTrue
        Test-Token (New-TestToken -Claims @{ aud = 'api://client-id' }) | Should -BeTrue
        Test-Token (New-TestToken -Claims @{ aud = @('other', 'client-id') }) | Should -BeTrue
    }

    It 'rejects expired tokens and tokens that are not valid yet, allowing five minutes of clock skew' {
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        Test-Token (New-TestToken -Claims @{ exp = $now - 400 }) | Should -BeFalse
        Test-Token (New-TestToken -Claims @{ exp = $now - 60 }) | Should -BeTrue
        Test-Token (New-TestToken -Claims @{ nbf = $now + 400 }) | Should -BeFalse
        Test-Token (New-TestToken -Claims @{ exp = 'never' }) | Should -BeFalse
    }

    It 'rejects a wrong issuer or audience' {
        Test-Token (New-TestToken -Claims @{ iss = 'https://evil.example.com/tenant/v2.0' }) | Should -BeFalse
        Test-Token (New-TestToken -Claims @{ iss = 'https://LOGIN.example.com/tenant/v2.0' }) | Should -BeFalse
        Test-Token (New-TestToken -Claims @{ aud = 'other-app' }) | Should -BeFalse
    }

    It 'rejects other algorithms, foreign keys, unknown key ids and tampered payloads' {
        Test-Token (New-TestToken -Header @{ alg = 'none' }) | Should -BeFalse
        Test-Token (New-TestToken -Header @{ alg = 'HS256' }) | Should -BeFalse
        Test-Token (New-TestToken -Key $script:OtherRsa) | Should -BeFalse
        Test-Token (New-TestToken -Header @{ kid = 'unknown' }) | Should -BeFalse

        $header, $payload, $signature = (New-TestToken) -split '\.'
        $forged = ConvertTo-TestSegment @{ iss = $script:Issuer; aud = 'client-id'; exp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() + 99999 }
        $payload | Should -Not -Be $forged
        Test-Token "$header.$forged.$signature" | Should -BeFalse
    }

    It 'rejects missing and malformed tokens without asking for signing keys' {
        InModuleScope PSMcpKnowledgeBase -Parameters @{ OAuth = $script:OAuth } {
            param($OAuth)
            Mock Get-McpOAuthSigningKey { throw 'must not be called' }
            Test-McpOAuthToken -AuthorizationHeader $null -OAuth $OAuth | Should -BeFalse
            Test-McpOAuthToken -AuthorizationHeader 'Bearer api-key-value' -OAuth $OAuth | Should -BeFalse
            Test-McpOAuthToken -AuthorizationHeader 'Basic a.b.c' -OAuth $OAuth | Should -BeFalse
            Test-McpOAuthToken -AuthorizationHeader 'Bearer bm90LWpzb24.e30.c2ln' -OAuth $OAuth | Should -BeFalse
        }
    }

    It 'rejects ID tokens (no scp, scope or roles) when no scope is configured' {
        Test-Token (New-TestToken -Claims @{ roles = $null }) | Should -BeFalse
        Test-Token (New-TestToken -Claims @{ roles = $null; scp = 'access_as_user' }) | Should -BeTrue
    }

    It 'requires the configured scope in scp or scope, also as the short name Entra ID uses' {
        $scoped = $script:OAuth.Clone()
        $scoped.Scope = 'api://client-id/access_as_user'
        Test-Token (New-TestToken) -OAuth $scoped | Should -BeFalse
        Test-Token (New-TestToken -Claims @{ scp = 'User.Read other' }) -OAuth $scoped | Should -BeFalse
        Test-Token (New-TestToken -Claims @{ scp = 'User.Read access_as_user' }) -OAuth $scoped | Should -BeTrue
        Test-Token (New-TestToken -Claims @{ scope = 'api://client-id/access_as_user' }) -OAuth $scoped | Should -BeTrue
    }
}
