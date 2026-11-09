BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpKnowledgeBaseRoot' {
    It 'returns the knowledgebases folder below the home path' {
        InModuleScope MCPPosh {
            $root = Get-McpKnowledgeBaseRoot
            $root | Should -Be (Join-Path (Get-McpHomePath) 'knowledgebases')
            Test-Path $root | Should -BeTrue
        }
    }
}
