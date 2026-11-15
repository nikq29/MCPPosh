BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/PSMcpKnowledgeBase.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'PSMcpKnowledgeBase'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpHomePath' {
    It 'returns PSMCPKB_HOME and creates it' {
        InModuleScope PSMcpKnowledgeBase -Parameters @{ Home = $script:TestHome } {
            param($Home)
            $previous = $env:PSMCPKB_HOME
            $env:PSMCPKB_HOME = Join-Path $Home 'nested/home'
            try {
                Get-McpHomePath | Should -Be ([System.IO.Path]::GetFullPath($env:PSMCPKB_HOME))
                Test-Path $env:PSMCPKB_HOME | Should -BeTrue
            }
            finally {
                $env:PSMCPKB_HOME = $previous
            }
        }
    }

    It 'falls back to .psmcpkb in the user profile' {
        InModuleScope PSMcpKnowledgeBase {
            $previous = $env:PSMCPKB_HOME
            $env:PSMCPKB_HOME = $null
            try {
                Get-McpHomePath | Should -BeLike '*.psmcpkb'
            }
            finally {
                $env:PSMCPKB_HOME = $previous
            }
        }
    }
}
