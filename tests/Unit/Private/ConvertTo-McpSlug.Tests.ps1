BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'ConvertTo-McpSlug' {
    It 'creates lowercase slugs with transliterated umlauts' {
        InModuleScope MCPPosh {
            ConvertTo-McpSlug -Text 'VPN: Fehler 809 beheben' | Should -Be 'vpn-fehler-809-beheben'
            ConvertTo-McpSlug -Text "$([char]0x00DC)bersicht Gr$([char]0x00F6)$([char]0x00DF)e" | Should -Be 'uebersicht-groesse'
            ConvertTo-McpSlug -Text "Caf$([char]0x00E9)" | Should -Be 'cafe'
        }
    }

    It 'limits the length and falls back to document' {
        InModuleScope MCPPosh {
            (ConvertTo-McpSlug -Text ('word ' * 30)).Length | Should -BeLessOrEqual 48
            ConvertTo-McpSlug -Text '!!!' | Should -Be 'document'
        }
    }
}
