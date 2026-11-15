BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/PSMcpKnowledgeBase.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'PSMcpKnowledgeBase'
    New-McpKnowledgeBase -Name Old | Out-Null
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Remove-McpKnowledgeBase' {
    It 'keeps the knowledge base with -WhatIf' {
        Remove-McpKnowledgeBase -Name Old -WhatIf
        Get-McpKnowledgeBase -Name Old | Should -Not -BeNullOrEmpty
    }

    It 'refuses to remove a knowledge base served by a running server' {
        InModuleScope PSMcpKnowledgeBase {
            $kb = Resolve-McpKnowledgeBase -KnowledgeBase Old
            Mock Get-McpServerState { [pscustomobject]@{ kbPath = $kb.Path; Status = 'Running' } }
            Remove-McpKnowledgeBase -Name Old -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable err
            $err | Should -Not -BeNullOrEmpty
            Test-Path $kb.Path | Should -BeTrue
        }
    }

    It 'deletes the knowledge base' {
        Remove-McpKnowledgeBase -Name Old -Confirm:$false
        Get-McpKnowledgeBase -Name Old -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Test-Path (Join-Path $env:PSMCPKB_HOME 'knowledgebases/Old') | Should -BeFalse
    }
}
