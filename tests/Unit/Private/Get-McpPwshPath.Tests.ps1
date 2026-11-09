BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpPwshPath' {
    It 'returns an existing pwsh executable' {
        InModuleScope MCPPosh {
            $path = Get-McpPwshPath
            Test-Path -LiteralPath $path | Should -BeTrue
            [System.IO.Path]::GetFileNameWithoutExtension($path) | Should -Be 'pwsh'
        }
    }
}
