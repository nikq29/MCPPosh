BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/PSMcpKnowledgeBase.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'PSMcpKnowledgeBase'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpOAuthSigningKey' {
    BeforeEach {
        InModuleScope PSMcpKnowledgeBase {
            $script:McpOAuthKeyCache = @{}
            Mock Invoke-RestMethod -ParameterFilter { $Uri -eq 'https://idp.example.com/.well-known/openid-configuration' } { [pscustomobject]@{ jwks_uri = 'https://idp.example.com/keys' } }
            Mock Invoke-RestMethod -ParameterFilter { $Uri -eq 'https://idp.example.com/keys' } {
                [pscustomobject]@{ keys = @(
                        [pscustomobject]@{ kty = 'RSA'; use = 'enc'; kid = 'enc1'; n = 'x'; e = 'AQAB' }
                        [pscustomobject]@{ kty = 'RSA'; use = 'sig'; kid = 'key1'; n = 'x'; e = 'AQAB' }
                    )
                }
            }
        }
    }

    It 'reads the key set through the OpenID configuration and returns signing keys by key id' {
        InModuleScope PSMcpKnowledgeBase {
            (Get-McpOAuthSigningKey -Issuer 'https://idp.example.com/' -KeyId 'key1').kid | Should -Be 'key1'
            Get-McpOAuthSigningKey -Issuer 'https://idp.example.com/' -KeyId 'enc1' | Should -BeNullOrEmpty
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $Uri -eq 'https://idp.example.com/keys' }
        }
    }

    It 'caches the key set and downloads it again for unknown key ids at most once per minute' {
        InModuleScope PSMcpKnowledgeBase {
            $issuer = 'https://idp.example.com'
            $null = Get-McpOAuthSigningKey -Issuer $issuer -KeyId 'key1'
            $null = Get-McpOAuthSigningKey -Issuer $issuer -KeyId 'key1'
            Get-McpOAuthSigningKey -Issuer $issuer -KeyId 'rotated' | Should -BeNullOrEmpty
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $Uri -eq 'https://idp.example.com/keys' }

            $script:McpOAuthKeyCache[$issuer].FetchedAt = [datetime]::UtcNow.AddMinutes(-2)
            Get-McpOAuthSigningKey -Issuer $issuer -KeyId 'rotated' | Should -BeNullOrEmpty
            Should -Invoke Invoke-RestMethod -Times 2 -Exactly -ParameterFilter { $Uri -eq 'https://idp.example.com/keys' }
        }
    }

    It 'downloads the key set again after a day even when the key id is known, so withdrawn keys stop working' {
        InModuleScope PSMcpKnowledgeBase {
            $issuer = 'https://idp.example.com'
            $null = Get-McpOAuthSigningKey -Issuer $issuer -KeyId 'key1'
            $script:McpOAuthKeyCache[$issuer].FetchedAt = [datetime]::UtcNow.AddHours(-23)
            $null = Get-McpOAuthSigningKey -Issuer $issuer -KeyId 'key1'
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $Uri -eq 'https://idp.example.com/keys' }

            $script:McpOAuthKeyCache[$issuer].FetchedAt = [datetime]::UtcNow.AddHours(-25)
            Mock Invoke-RestMethod -ParameterFilter { $Uri -eq 'https://idp.example.com/keys' } { [pscustomobject]@{ keys = @() } }
            Get-McpOAuthSigningKey -Issuer $issuer -KeyId 'key1' | Should -BeNullOrEmpty
            Should -Invoke Invoke-RestMethod -Times 2 -Exactly -ParameterFilter { $Uri -eq 'https://idp.example.com/keys' }
        }
    }

    It 'throws download errors and does not retry within a minute' {
        InModuleScope PSMcpKnowledgeBase {
            Mock Invoke-RestMethod { throw 'identity provider down' }
            { Get-McpOAuthSigningKey -Issuer 'https://down.example.com' -KeyId 'key1' } | Should -Throw '*identity provider down*'
            Get-McpOAuthSigningKey -Issuer 'https://down.example.com' -KeyId 'key1' | Should -BeNullOrEmpty
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly
        }
    }
}
