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

Describe 'ConvertTo-McpMarkdownTableCell' {
    It 'escapes pipes and removes line breaks' {
        InModuleScope MCPPosh {
            ConvertTo-McpMarkdownTableCell -Value "Service desk | 24/7`r`n Phone" | Should -Be 'Service desk \| 24/7 Phone'
            ConvertTo-McpMarkdownTableCell -Value $null | Should -Be ''
        }
    }
}
