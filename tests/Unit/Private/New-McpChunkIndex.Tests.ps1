BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    $script:Files = Join-Path $script:TestHome 'files'
    New-Item -ItemType Directory -Path $script:Files -Force | Out-Null
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'New-McpChunkIndex' {
    It 'computes term frequencies with weighted headings and titles' {
        InModuleScope MCPPosh {
            $chunks = @(New-McpChunkIndex -Content "# Backup`n`nThe backup runs nightly." -Title 'Operations')
            $chunks.Count | Should -Be 1
            $chunks[0].heading | Should -Be 'Backup'
            $chunks[0].tf['backup'] | Should -Be 3 -Because 'the text counts once and the heading twice'
            $chunks[0].tf['operation'] | Should -Be 1
            $chunks[0].len | Should -BeGreaterThan 3
        }
    }

    It 'skips sections without searchable text' {
        InModuleScope MCPPosh {
            $chunks = New-McpChunkIndex -Content "# Only heading`n`n## Another" -Title 'x'
            $chunks.Count | Should -Be 0
        }
    }
}
