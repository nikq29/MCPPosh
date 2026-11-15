BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/PSMcpKnowledgeBase.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'PSMcpKnowledgeBase'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'New-McpRpcError' {
    It 'creates an exception that carries the error code and data' {
        InModuleScope PSMcpKnowledgeBase {
            $exception = New-McpRpcError -Code -32002 -Message 'Resource not found' -Data 'uri'
            $exception | Should -BeOfType [System.InvalidOperationException]
            $exception.Message | Should -Be 'Resource not found'
            $exception.Data['McpRpcCode'] | Should -Be -32002
            $exception.Data['McpRpcData'] | Should -Be 'uri'
        }
    }
}
