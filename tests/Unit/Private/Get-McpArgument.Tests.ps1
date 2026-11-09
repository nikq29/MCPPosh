BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpArgument' {
    It 'returns typed values and defaults' {
        InModuleScope MCPPosh {
            $arguments = [ordered]@{ query = 'vpn'; limit = 3L; tags = @('a', 'b'); csv = 'x, y' }
            Get-McpArgument -Arguments $arguments -Name query -Required | Should -Be 'vpn'
            Get-McpArgument -Arguments $arguments -Name limit -Type Integer -Minimum 1 -Maximum 20 | Should -Be 3
            $tags = Get-McpArgument -Arguments $arguments -Name tags -Type StringArray
            $tags | Should -Be @('a', 'b')
            $csv = Get-McpArgument -Arguments $arguments -Name csv -Type StringArray
            $csv | Should -Be @('x', 'y')
            Get-McpArgument -Arguments $arguments -Name missing -Default 5 | Should -Be 5
        }
    }

    It 'accepts whole doubles and numeric strings for integers' {
        InModuleScope MCPPosh {
            Get-McpArgument -Arguments ([ordered]@{ n = 4.0 }) -Name n -Type Integer | Should -Be 4
            Get-McpArgument -Arguments ([ordered]@{ n = '7' }) -Name n -Type Integer | Should -Be 7
        }
    }

    It 'throws argument errors for invalid values' {
        InModuleScope MCPPosh {
            { Get-McpArgument -Arguments ([ordered]@{}) -Name query -Required } | Should -Throw '*Missing required argument*'
            { Get-McpArgument -Arguments ([ordered]@{ query = ' ' }) -Name query -Required } | Should -Throw '*must not be empty*'
            { Get-McpArgument -Arguments ([ordered]@{ query = 1L }) -Name query } | Should -Throw '*must be a string*'
            { Get-McpArgument -Arguments ([ordered]@{ n = 'x' }) -Name n -Type Integer } | Should -Throw '*must be an integer*'
            { Get-McpArgument -Arguments ([ordered]@{ n = 50L }) -Name n -Type Integer -Maximum 20 } | Should -Throw '*between*'
            { Get-McpArgument -Arguments ([ordered]@{ t = @(1L) }) -Name t -Type StringArray } | Should -Throw '*array of strings*'
        }
    }
}
