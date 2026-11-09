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

Describe 'Get-McpMarkdownTitle' {
    It 'returns the first level-one heading' {
        InModuleScope MCPPosh {
            Get-McpMarkdownTitle -Markdown "Intro`n`n## Sub`n`n# Installation #`n`nText" | Should -Be 'Installation'
            Get-McpMarkdownTitle -Markdown 'No heading' | Should -BeNullOrEmpty
        }
    }
}
