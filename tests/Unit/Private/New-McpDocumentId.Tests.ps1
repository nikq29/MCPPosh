BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'New-McpDocumentId' {
    It 'creates readable ids with a random suffix' {
        InModuleScope MCPPosh {
            New-McpDocumentId -Title 'Installation Guide' | Should -Match '^installation-guide-[0-9a-f]{6}$'
        }
    }

    It 'avoids existing ids' {
        InModuleScope MCPPosh {
            $ids = 1..20 | ForEach-Object { New-McpDocumentId -Title 'x' }
            @($ids | Sort-Object -Unique).Count | Should -Be 20
            New-McpDocumentId -Title 'x' -ExistingIds $ids | Should -Not -BeIn $ids
        }
    }
}
