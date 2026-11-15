BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Test-McpKnowledgeBaseName' {
    It 'accepts valid names' -ForEach @('Default', 'team-docs', 'a.b_c', 'X1') {
        InModuleScope MCPPosh -Parameters @{ Name = $_ } { param($Name) Test-McpKnowledgeBaseName -Name $Name | Should -BeTrue }
    }

    It 'rejects invalid names' -ForEach @('', '-start', 'with space', 'a/b', ('x' * 65)) {
        InModuleScope MCPPosh -Parameters @{ Name = $_ } { param($Name) Test-McpKnowledgeBaseName -Name $Name | Should -BeFalse }
    }
}

Describe 'Test-McpKnowledgeBaseName (trailing newline)' {
    It 'rejects names with a trailing newline' {
        InModuleScope MCPPosh {
            Test-McpKnowledgeBaseName -Name "Contoso`n" | Should -BeFalse
        }
    }
}
