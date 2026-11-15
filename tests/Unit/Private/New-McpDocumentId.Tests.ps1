BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/PSMcpKnowledgeBase.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'PSMcpKnowledgeBase'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'New-McpDocumentId' {
    It 'creates readable ids with a random suffix' {
        InModuleScope PSMcpKnowledgeBase {
            New-McpDocumentId -Title 'Installation Guide' | Should -Match '^installation-guide-[0-9a-f]{6}$'
        }
    }

    It 'avoids existing ids' {
        InModuleScope PSMcpKnowledgeBase {
            $ids = 1..20 | ForEach-Object { New-McpDocumentId -Title 'x' }
            @($ids | Sort-Object -Unique).Count | Should -Be 20
            New-McpDocumentId -Title 'x' -ExistingIds $ids | Should -Not -BeIn $ids
        }
    }
}
