BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/PSMcpKnowledgeBase.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'PSMcpKnowledgeBase'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpServerStateFile' {
    It 'returns the state file path for a knowledge base and port' {
        InModuleScope PSMcpKnowledgeBase {
            Get-McpServerStateFile -KnowledgeBaseName 'Contoso Docs' -Port 5050 | Should -Be (Join-Path (Get-McpServerStateRoot) 'contoso-docs-5050.json')
        }
    }
}
