BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    New-McpKnowledgeBase -Name Team -Description 'Old' | Out-Null
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Set-McpKnowledgeBase' {
    It 'changes the description and bumps the revision' {
        $before = (Get-McpKnowledgeBase -Name Team).Revision
        Set-McpKnowledgeBase -Name Team -Description 'New description'
        $kb = Get-McpKnowledgeBase -Name Team
        $kb.Description | Should -Be 'New description'
        $kb.Revision | Should -BeGreaterThan $before
    }

    It 'returns the knowledge base with -PassThru' {
        (Set-McpKnowledgeBase -Name Team -Description 'Again' -PassThru).Description | Should -Be 'Again'
    }

    It 'does nothing with -WhatIf' {
        Set-McpKnowledgeBase -Name Team -Description 'Ignored' -WhatIf
        (Get-McpKnowledgeBase -Name Team).Description | Should -Be 'Again'
    }
}
