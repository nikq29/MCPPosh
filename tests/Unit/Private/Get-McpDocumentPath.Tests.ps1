BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/PSMcpKnowledgeBase.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'PSMcpKnowledgeBase'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpDocumentPath' {
    It 'returns the content and index paths' {
        InModuleScope PSMcpKnowledgeBase {
            $paths = Get-McpDocumentPath -KbPath '/kb' -Id 'doc-1'
            $paths.Content | Should -Be ([System.IO.Path]::Combine('/kb', 'documents', 'doc-1.md'))
            $paths.Index | Should -Be ([System.IO.Path]::Combine('/kb', 'index', 'doc-1.json'))
        }
    }
}

Describe 'Get-McpDocumentPath (invalid ids)' {
    It 'throws for ids that would address files outside the knowledge base' {
        InModuleScope PSMcpKnowledgeBase {
            { Get-McpDocumentPath -KbPath '/kb' -Id '../../etc/secret' } | Should -Throw '*Invalid document id*'
            { Get-McpDocumentPath -KbPath '/kb' -Id '/etc/secret' } | Should -Throw '*Invalid document id*'
        }
    }
}
