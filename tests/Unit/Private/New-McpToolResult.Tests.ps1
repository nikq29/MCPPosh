BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'New-McpToolResult' {
    It 'creates text results with structured content and error flag' {
        InModuleScope MCPPosh {
            $result = New-McpToolResult -Text 'hello' -Structured ([ordered]@{ a = 1 })
            $result.content[0].type | Should -Be 'text'
            $result.content[0].text | Should -Be 'hello'
            $result.structuredContent.a | Should -Be 1
            $result.Contains('isError') | Should -BeFalse
            (New-McpToolResult -Text 'bad' -IsError).isError | Should -BeTrue
        }
    }
}
