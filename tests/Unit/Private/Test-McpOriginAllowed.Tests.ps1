BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Test-McpOriginAllowed' {
    It 'allows requests without origin and listed origins' {
        InModuleScope MCPPosh {
            Test-McpOriginAllowed -Origin $null -Settings @{ AllowedOrigins = @(); IsLoopback = $true } | Should -BeTrue
            Test-McpOriginAllowed -Origin 'https://app.example.com' -Settings @{ AllowedOrigins = @('https://app.example.com'); IsLoopback = $true } | Should -BeTrue
            Test-McpOriginAllowed -Origin 'https://other.example.com' -Settings @{ AllowedOrigins = @('https://app.example.com'); IsLoopback = $false } | Should -BeFalse
        }
    }

    It 'only allows local origins for loopback servers without list' {
        InModuleScope MCPPosh {
            Test-McpOriginAllowed -Origin 'http://localhost:3000' -Settings @{ AllowedOrigins = @(); IsLoopback = $true } | Should -BeTrue
            Test-McpOriginAllowed -Origin 'https://evil.example.com' -Settings @{ AllowedOrigins = @(); IsLoopback = $true } | Should -BeFalse
            Test-McpOriginAllowed -Origin 'null' -Settings @{ AllowedOrigins = @(); IsLoopback = $true } | Should -BeFalse
            Test-McpOriginAllowed -Origin 'https://any.example.com' -Settings @{ AllowedOrigins = @(); IsLoopback = $false } | Should -BeTrue
        }
    }
}
