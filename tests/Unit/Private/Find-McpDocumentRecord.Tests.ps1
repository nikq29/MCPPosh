BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Find-McpDocumentRecord' {
    BeforeAll {
        $script:Records = @(
            [ordered]@{ id = 'a-1'; sourceType = 'File'; source = '/docs/a.md'; title = 'A' }
            [ordered]@{ id = 'b-2'; sourceType = 'Inline'; source = $null; title = 'Note' }
            [ordered]@{ id = 'c-3'; sourceType = 'Agent'; source = $null; title = 'Note' }
        )
    }

    It 'finds records by id, source and title' {
        InModuleScope MCPPosh -Parameters @{ Records = $script:Records } {
            param($Records)
            (Find-McpDocumentRecord -Documents $Records -Id 'b-2').title | Should -Be 'Note'
            (Find-McpDocumentRecord -Documents $Records -SourceType File -Source '/docs/a.md').id | Should -Be 'a-1'
            (Find-McpDocumentRecord -Documents $Records -SourceType Inline -Title 'Note').id | Should -Be 'b-2'
            (Find-McpDocumentRecord -Documents $Records -SourceType Agent -Title 'Note').id | Should -Be 'c-3'
        }
    }

    It 'returns $null when nothing matches' {
        InModuleScope MCPPosh -Parameters @{ Records = $script:Records } {
            param($Records)
            Find-McpDocumentRecord -Documents $Records -Id 'missing' | Should -BeNullOrEmpty
            Find-McpDocumentRecord -Documents @() -SourceType File -Source '/x' | Should -BeNullOrEmpty
        }
    }
}
