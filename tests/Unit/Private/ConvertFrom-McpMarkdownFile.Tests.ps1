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

Describe 'ConvertFrom-McpMarkdownFile' {
    It 'reads front matter title and tags and removes the front matter' {
        InModuleScope MCPPosh -Parameters @{ Files = $script:Files } {
            param($Files)
            $path = Join-Path $Files 'fm.md'
            Set-Content -Path $path -Value "---`ntitle: My Title`ntags:`n  - one`n  - two`n---`n# Heading`n`nText"
            $result = ConvertFrom-McpMarkdownFile -Path $path
            $result.Title | Should -Be 'My Title'
            $result.Tags | Should -Be @('one', 'two')
            $result.Content | Should -Not -Match 'title:'
        }
    }

    It 'uses the first heading as title' {
        InModuleScope MCPPosh -Parameters @{ Files = $script:Files } {
            param($Files)
            $path = Join-Path $Files 'heading.md'
            Set-Content -Path $path -Value "Intro`n`n# Real Title`n`nmore"
            (ConvertFrom-McpMarkdownFile -Path $path).Title | Should -Be 'Real Title'
        }
    }
}
