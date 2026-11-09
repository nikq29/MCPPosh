BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpContentSummary' {
    It 'uses the first paragraph without Markdown formatting' {
        InModuleScope MCPPosh {
            Get-McpContentSummary -Content "# Backup`n`nThe nightly **backup** runs at [02:00](http://x).`n`nSecond paragraph." | Should -Be 'The nightly backup runs at 02:00.'
        }
    }

    It 'skips code blocks and shortens long summaries' {
        InModuleScope MCPPosh {
            Get-McpContentSummary -Content "``````n# not a heading`n```````nReal text" | Should -Be 'Real text'
            $summary = Get-McpContentSummary -Content ('word ' * 100) -MaxLength 50
            $summary.Length | Should -BeLessOrEqual 51
            $summary[-1] | Should -Be ([char]0x2026)
        }
    }
}
