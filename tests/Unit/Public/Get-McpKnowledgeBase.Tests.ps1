BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    New-McpKnowledgeBase -Name Alpha -Description 'First' | Out-Null
    New-McpKnowledgeBase -Name Beta | Out-Null
    Add-McpDocument -KnowledgeBase Alpha -Title 'Doc' -Content 'Text' -Tags one | Out-Null
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpKnowledgeBase' {
    It 'lists all knowledge bases' {
        (Get-McpKnowledgeBase).Name | Should -Contain 'Alpha'
        (Get-McpKnowledgeBase).Name | Should -Contain 'Beta'
    }

    It 'filters by name with wildcards' {
        @(Get-McpKnowledgeBase -Name 'Al*').Name | Should -Be @('Alpha')
    }

    It 'returns document statistics' {
        $kb = Get-McpKnowledgeBase -Name Alpha
        $kb.Documents | Should -Be 1
        $kb.Tags | Should -Be @('one')
        $kb.Characters | Should -BeGreaterThan 0
        $kb.Revision | Should -BeGreaterThan 0
    }

    It 'resolves a knowledge base by path' {
        $path = Join-Path $env:MCPPOSH_HOME 'knowledgebases/Beta'
        (Get-McpKnowledgeBase -Name $path).Name | Should -Be 'Beta'
    }

    It 'writes an error for unknown names' {
        Get-McpKnowledgeBase -Name Missing -ErrorAction SilentlyContinue -ErrorVariable err | Should -BeNullOrEmpty
        $err | Should -Not -BeNullOrEmpty
    }
}
