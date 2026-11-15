BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/PSMcpKnowledgeBase.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'PSMcpKnowledgeBase'
    $script:Files = Join-Path $script:TestHome 'files'
    New-Item -ItemType Directory -Path $script:Files -Force | Out-Null
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpHtmlInnerText' {
    It 'removes tags, decodes entities and collapses whitespace' {
        InModuleScope PSMcpKnowledgeBase {
            Get-McpHtmlInnerText -Html "<b>Fish &amp;</b>`n   <i>Chips</i>" | Should -Be 'Fish & Chips'
        }
    }
}
