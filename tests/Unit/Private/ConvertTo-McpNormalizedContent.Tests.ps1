BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'ConvertTo-McpNormalizedContent' {
    It 'normalizes line endings, trailing whitespace and blank lines' {
        InModuleScope MCPPosh {
            ConvertTo-McpNormalizedContent -Content "`r`n# Title  `r`nText`t`r`n`r`n" | Should -Be "# Title`nText`n"
        }
    }

    It 'removes a byte order mark and handles empty content' {
        InModuleScope MCPPosh {
            ConvertTo-McpNormalizedContent -Content ([string][char]0xFEFF + 'x') | Should -Be "x`n"
            ConvertTo-McpNormalizedContent -Content '' | Should -Be "`n"
        }
    }
}
