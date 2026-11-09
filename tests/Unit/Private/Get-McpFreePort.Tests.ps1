BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpFreePort' {
    It 'returns a port that can be bound' {
        InModuleScope MCPPosh {
            $port = Get-McpFreePort
            $port | Should -BeGreaterThan 0
            Test-McpPortAvailable -Port $port | Should -BeTrue
        }
    }
}
