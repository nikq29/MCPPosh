BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/PSMcpKnowledgeBase.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'PSMcpKnowledgeBase'
    New-McpKnowledgeBase -Name Contoso | Out-Null
    New-McpKnowledgeBase -Name Other | Out-Null
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpKnowledgeBaseArgumentCompletion' {
    It 'completes knowledge base names' {
        InModuleScope PSMcpKnowledgeBase {
            $results = @(Get-McpKnowledgeBaseArgumentCompletion -commandName 'Get-McpDocument' -parameterName 'KnowledgeBase' -wordToComplete 'Con' -commandAst $null -fakeBoundParameters @{})
            $results.CompletionText | Should -Be @('Contoso')
            $results[0] | Should -BeOfType [System.Management.Automation.CompletionResult]
        }
    }
}
