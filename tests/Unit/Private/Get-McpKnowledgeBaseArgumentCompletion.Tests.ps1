BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    New-McpKnowledgeBase -Name Contoso | Out-Null
    New-McpKnowledgeBase -Name Other | Out-Null
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpKnowledgeBaseArgumentCompletion' {
    It 'completes knowledge base names' {
        InModuleScope MCPPosh {
            $results = @(Get-McpKnowledgeBaseArgumentCompletion -commandName 'Get-McpDocument' -parameterName 'KnowledgeBase' -wordToComplete 'Con' -commandAst $null -fakeBoundParameters @{})
            $results.CompletionText | Should -Be @('Contoso')
            $results[0] | Should -BeOfType [System.Management.Automation.CompletionResult]
        }
    }
}
