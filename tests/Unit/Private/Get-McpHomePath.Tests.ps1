BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpHomePath' {
    It 'returns MCPPOSH_HOME and creates it' {
        InModuleScope MCPPosh -Parameters @{ Home = $script:TestHome } {
            param($Home)
            $previous = $env:MCPPOSH_HOME
            $env:MCPPOSH_HOME = Join-Path $Home 'nested/home'
            try {
                Get-McpHomePath | Should -Be ([System.IO.Path]::GetFullPath($env:MCPPOSH_HOME))
                Test-Path $env:MCPPOSH_HOME | Should -BeTrue
            }
            finally {
                $env:MCPPOSH_HOME = $previous
            }
        }
    }

    It 'falls back to .mcpposh in the user profile' {
        InModuleScope MCPPosh {
            $previous = $env:MCPPOSH_HOME
            $env:MCPPOSH_HOME = $null
            try {
                Get-McpHomePath | Should -BeLike '*.mcpposh'
            }
            finally {
                $env:MCPPOSH_HOME = $previous
            }
        }
    }
}
