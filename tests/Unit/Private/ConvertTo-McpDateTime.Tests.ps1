BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'ConvertTo-McpDateTime' {
    It 'converts ISO strings to UTC DateTime values' {
        InModuleScope MCPPosh {
            $value = ConvertTo-McpDateTime -Value '2026-01-31T08:15:00.000Z'
            $value | Should -BeOfType [datetime]
            $value.ToUniversalTime().Hour | Should -Be 8
        }
    }

    It 'returns DateTime values unchanged and $null for empty values' {
        InModuleScope MCPPosh {
            $now = Get-Date
            ConvertTo-McpDateTime -Value $now | Should -Be $now
            ConvertTo-McpDateTime -Value '' | Should -BeNullOrEmpty
            ConvertTo-McpDateTime -Value $null | Should -BeNullOrEmpty
        }
    }
}
