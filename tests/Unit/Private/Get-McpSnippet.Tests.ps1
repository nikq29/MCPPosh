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

Describe 'Get-McpSnippet' {
    It 'returns short texts unchanged with collapsed whitespace' {
        InModuleScope MCPPosh { Get-McpSnippet -Text "a`n  b" -Query 'a' | Should -Be 'a b' }
    }

    It 'centers long texts around the first query match' {
        InModuleScope MCPPosh {
            $text = ('filler ' * 80) + 'the vpnagent restart is here ' + ('tail ' * 80)
            $snippet = Get-McpSnippet -Text $text -Query 'restart vpnagent' -Length 100
            $snippet | Should -Match 'vpnagent'
            $snippet[0] | Should -Be ([char]0x2026)
            $snippet[-1] | Should -Be ([char]0x2026)
        }
    }
}
