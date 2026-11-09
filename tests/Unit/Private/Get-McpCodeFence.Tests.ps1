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

Describe 'Get-McpCodeFence' {
    It 'returns three backticks for normal code and a longer fence otherwise' {
        InModuleScope MCPPosh {
            Get-McpCodeFence -Text 'Write-Output 1' | Should -Be '```'
            Get-McpCodeFence -Text "``````md`nx`n``````" | Should -Be '````'
        }
    }
}
