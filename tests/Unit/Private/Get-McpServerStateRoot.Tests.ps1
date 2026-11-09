BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpServerStateRoot' {
    It 'returns the servers folder below the home path' {
        InModuleScope MCPPosh {
            $root = Get-McpServerStateRoot
            $root | Should -Be (Join-Path (Get-McpHomePath) 'servers')
            Test-Path $root | Should -BeTrue
        }
    }
}
