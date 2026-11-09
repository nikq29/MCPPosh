BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Test-McpApiKey' {
    It 'accepts valid keys from the Authorization and X-API-Key headers' {
        InModuleScope MCPPosh {
            Test-McpApiKey -AuthorizationHeader 'Bearer secret' -ApiKeys 'old', 'secret' | Should -BeTrue
            Test-McpApiKey -ApiKeyHeader ' secret ' -ApiKeys 'secret' | Should -BeTrue
        }
    }

    It 'rejects missing and wrong keys' {
        InModuleScope MCPPosh {
            Test-McpApiKey -AuthorizationHeader 'Bearer wrong' -ApiKeys 'secret' | Should -BeFalse
            Test-McpApiKey -AuthorizationHeader 'Basic secret' -ApiKeys 'secret' | Should -BeFalse
            Test-McpApiKey -ApiKeys 'secret' | Should -BeFalse
        }
    }
}
