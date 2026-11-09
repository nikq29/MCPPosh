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

Describe 'Get-McpToken' {
    It 'lowercases, folds diacritics, removes stop words and stems' {
        InModuleScope MCPPosh {
            $tokens = Get-McpToken -Text "Die Server-Konfigurationen f$([char]0x00FC)r Gr$([char]0x00F6)$([char]0x00DF)e"
            $tokens | Should -Contain 'serv'
            $tokens | Should -Contain 'konfiguration'
            $tokens | Should -Contain 'gros'
            $tokens | Should -Not -Contain 'die'
            $tokens | Should -Not -Contain 'fur'
        }
    }

    It 'stems singular and plural forms to the same token' {
        InModuleScope MCPPosh {
            (Get-McpToken -Text 'servers')[0] | Should -Be (Get-McpToken -Text 'server')[0]
            (Get-McpToken -Text 'Dokumente')[0] | Should -Be (Get-McpToken -Text 'Dokumenten')[0]
        }
    }

    It 'returns an empty array for empty text' {
        InModuleScope MCPPosh {
            , (Get-McpToken -Text '') | Should -BeOfType [string[]]
            (Get-McpToken -Text '   ').Count | Should -Be 0
        }
    }
}
