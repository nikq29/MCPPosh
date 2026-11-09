BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'New-McpErrorResponse' {
    It 'creates an error response with optional data' {
        InModuleScope MCPPosh {
            $response = New-McpErrorResponse -Id 7 -Code -32601 -Message 'Method not found' -Data ([ordered]@{ method = 'x' })
            $response.jsonrpc | Should -Be '2.0'
            $response.id | Should -Be 7
            $response.error.code | Should -Be -32601
            $response.error.data.method | Should -Be 'x'
            (New-McpErrorResponse -Id $null -Code -32700 -Message 'Parse error').error.Contains('data') | Should -BeFalse
        }
    }
}
