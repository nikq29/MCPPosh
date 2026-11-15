BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/PSMcpKnowledgeBase.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'PSMcpKnowledgeBase'
    New-McpKnowledgeBase -Name Kb | Out-Null
    New-McpKnowledgeBase -Name Default | Out-Null
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Resolve-McpKnowledgeBase' {
    It 'resolves a knowledge base by name' {
        InModuleScope PSMcpKnowledgeBase {
            $kb = Resolve-McpKnowledgeBase -KnowledgeBase Kb
            $kb.Name | Should -Be 'Kb'
            $kb.Path | Should -Be (Join-Path (Get-McpKnowledgeBaseRoot) 'Kb')
        }
    }

    It 'resolves a knowledge base by path' {
        InModuleScope PSMcpKnowledgeBase {
            $path = Join-Path (Get-McpKnowledgeBaseRoot) 'Kb'
            (Resolve-McpKnowledgeBase -KnowledgeBase $path).Name | Should -Be 'Kb'
        }
    }

    It 'creates missing knowledge bases only with -CreateIfMissing' {
        InModuleScope PSMcpKnowledgeBase {
            { Resolve-McpKnowledgeBase -KnowledgeBase Missing } | Should -Throw '*New-McpKnowledgeBase*'
            (Resolve-McpKnowledgeBase -KnowledgeBase Created -CreateIfMissing).Name | Should -Be 'Created'
            (Resolve-McpKnowledgeBase -KnowledgeBase '').Name | Should -Be 'Default' -Because 'empty values resolve to Default'
        }
    }

    It 'rejects invalid names' {
        InModuleScope PSMcpKnowledgeBase {
            { Resolve-McpKnowledgeBase -KnowledgeBase 'bad name!' } | Should -Throw '*Invalid knowledge base name*'
        }
    }
}
