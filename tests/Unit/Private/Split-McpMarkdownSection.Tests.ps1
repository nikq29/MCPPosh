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

Describe 'Split-McpMarkdownSection' {
    It 'splits by headings, keeps the heading path and ignores headings in code fences' {
        InModuleScope MCPPosh {
            $chunks = @(Split-McpMarkdownSection -Content "# A`n`nText A`n`n## B`n`nText B`n`n``````md`n# not a heading`n```````n`n# C`n`nText C")
            $chunks.Count | Should -Be 3
            $chunks[1].heading | Should -Be 'A > B'
            $chunks[1].text | Should -Match 'not a heading'
            $chunks[2].heading | Should -Be 'C'
        }
    }

    It 'splits long sections below the size limit' {
        InModuleScope MCPPosh {
            $paragraphs = 1..40 | ForEach-Object { "Paragraph $_ " + ('word ' * 20) }
            $chunks = @(Split-McpMarkdownSection -Content ("# Long`n`n" + ($paragraphs -join "`n`n")) -MaxChars 500)
            $chunks.Count | Should -BeGreaterThan 5
            $chunks | ForEach-Object { $_.text.Length | Should -BeLessOrEqual 500 }
        }
    }
}
