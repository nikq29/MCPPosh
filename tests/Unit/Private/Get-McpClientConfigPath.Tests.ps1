BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpClientConfigPath' {
    It 'returns the configuration locations of the clients' {
        InModuleScope MCPPosh {
            Get-McpClientConfigPath -Client ClaudeDesktop | Should -Match 'claude_desktop_config\.json$'
            Get-McpClientConfigPath -Client Cursor | Should -Match 'mcp\.json$'
            Get-McpClientConfigPath -Client VSCode | Should -Match '\.vscode/mcp\.json'
            Get-McpClientConfigPath -Client ClaudeCode | Should -Match 'claude mcp add'
            Get-McpClientConfigPath -Client Generic | Should -BeNullOrEmpty
        }
    }
}
