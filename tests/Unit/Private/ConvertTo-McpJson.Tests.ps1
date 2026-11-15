BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/PSMcpKnowledgeBase.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'PSMcpKnowledgeBase'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'ConvertTo-McpJson' {
    It 'serializes compact JSON and keeps single-element arrays' {
        InModuleScope PSMcpKnowledgeBase {
            ConvertTo-McpJson -InputObject ([ordered]@{ a = @('x') }) -Compress | Should -Be '{"a":["x"]}'
            ConvertTo-McpJson -InputObject @('x') -Compress | Should -Be '["x"]'
        }
    }

    It 'produces indented JSON without -Compress' {
        InModuleScope PSMcpKnowledgeBase {
            ConvertTo-McpJson -InputObject ([ordered]@{ a = 1 }) | Should -Match "`n"
        }
    }
}
