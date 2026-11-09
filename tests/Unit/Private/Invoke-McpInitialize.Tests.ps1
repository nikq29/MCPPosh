BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    New-McpKnowledgeBase -Name Proto -Description 'Protocol tests' | Out-Null
    Add-McpDocument -KnowledgeBase Proto -Title 'Backup' -Content "# Backup`n`nThe nightly backup runs at 02:00 with Veeam." -Tags ops | Out-Null
    Add-McpDocument -KnowledgeBase Proto -Title 'Onboarding' -Content ("# Onboarding`n`n" + ('New employees receive their laptop on the first day. ' * 40)) -Tags hr | Out-Null
    $script:Context = New-McpTestContext -KnowledgeBase Proto
    $script:WriteContext = New-McpTestContext -KnowledgeBase Proto -AllowWrite
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Invoke-McpInitialize' {
    It 'negotiates a supported protocol version' {
        (Invoke-McpTestMessage -KnowledgeBase Proto -Message @{ jsonrpc = '2.0'; id = 1; method = 'initialize'; params = @{ protocolVersion = '2025-03-26'; clientInfo = @{ name = 'pester'; version = '1' } } }).result.protocolVersion | Should -Be '2025-03-26'
    }

    It 'falls back to the newest version and announces capabilities' {
        $result = (Invoke-McpTestMessage -KnowledgeBase Proto -Message @{ jsonrpc = '2.0'; id = 1; method = 'initialize'; params = @{ protocolVersion = '1999-01-01' } }).result
        $result.protocolVersion | Should -Be '2025-11-25'
        $result.capabilities.tools | Should -Not -BeNullOrEmpty
        $result.capabilities.resources | Should -Not -BeNullOrEmpty
        $result.serverInfo.name | Should -Be 'MCPPosh'
        $result.instructions | Should -Match 'Protocol tests'
    }
}
