BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/PSMcpKnowledgeBase.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'PSMcpKnowledgeBase'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpPwshPath' {
    It 'returns an existing pwsh executable' {
        InModuleScope PSMcpKnowledgeBase {
            $path = Get-McpPwshPath
            Test-Path -LiteralPath $path | Should -BeTrue
            [System.IO.Path]::GetFileNameWithoutExtension($path) | Should -Be 'pwsh'
        }
    }
}
