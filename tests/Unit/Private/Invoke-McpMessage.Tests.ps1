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

Describe 'Invoke-McpMessage' {
    It 'returns a parse error for invalid JSON' {
        $response = Invoke-McpTestMessage -KnowledgeBase Proto -Message '{not json'
        $response.error.code | Should -Be -32700
        $response.id | Should -BeNullOrEmpty
    }

    It 'does not answer notifications and processes batches' {
        Invoke-McpTestMessage -KnowledgeBase Proto -Message @{ jsonrpc = '2.0'; method = 'notifications/initialized' } | Should -BeNullOrEmpty
        $batch = Invoke-McpTestMessage -KnowledgeBase Proto -Message '[{"jsonrpc":"2.0","id":1,"method":"ping"},{"jsonrpc":"2.0","method":"notifications/initialized"},{"jsonrpc":"2.0","id":2,"method":"ping"}]'
        @($batch).Count | Should -Be 2
        $batch.id | Should -Be @(1, 2)
        (Invoke-McpTestMessage -KnowledgeBase Proto -Message '[]').error.code | Should -Be -32600
    }

    It 'preserves string and numeric ids and keeps date-like strings' {
        (Invoke-McpTestMessage -KnowledgeBase Proto -Message '{"jsonrpc":"2.0","id":"abc-1","method":"ping"}').id | Should -Be 'abc-1'
        (Invoke-McpTestMessage -KnowledgeBase Proto -Message '{"jsonrpc":"2.0","id":42,"method":"ping"}').id | Should -Be 42
        $search = Invoke-McpTestMessage -KnowledgeBase Proto -Message @{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = @{ name = 'search_documentation'; arguments = @{ query = '2025-06-18' } } }
        $search.result.content[0].text | Should -Match '"2025-06-18"'
    }
}
