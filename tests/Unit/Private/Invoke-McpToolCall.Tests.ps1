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

Describe 'Invoke-McpToolCall' {
    It 'returns protocol errors for unknown tools and invalid params' {
        (Invoke-McpTestMessage -KnowledgeBase Proto -Message @{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = @{ name = 'nope' } }).error.code | Should -Be -32602
        (Invoke-McpTestMessage -KnowledgeBase Proto -Message @{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = @{ arguments = @{} } }).error.code | Should -Be -32602
        (Invoke-McpTestMessage -KnowledgeBase Proto -Message @{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = @{ name = 'list_documents'; arguments = 'x' } }).error.code | Should -Be -32602
    }

    It 'hides add_note without write access' {
        (Invoke-McpTestMessage -KnowledgeBase Proto -Message @{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = @{ name = 'add_note'; arguments = @{ title = 'x'; content = 'y' } } }).error.code | Should -Be -32602
    }

    It 'reports tool failures as tool errors' {
        $result = (Invoke-McpTestMessage -KnowledgeBase Proto -Message @{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = @{ name = 'search_documentation'; arguments = @{ limit = 3 } } }).result
        $result.isError | Should -BeTrue
        $result.content[0].text | Should -Match 'query'
    }
}

Describe 'Invoke-McpToolCall (error details)' {
    It 'hides the details of unexpected tool failures' {
        Mock -ModuleName MCPPosh Invoke-McpSearchTool { throw [System.IO.IOException]::new('Access to /secret/path denied') }
        $result = (Invoke-McpTestMessage -KnowledgeBase Proto -Message @{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = @{ name = 'search_documentation'; arguments = @{ query = 'x' } } }).result
        $result.isError | Should -BeTrue
        $result.content[0].text | Should -Not -Match 'secret'
        $result.content[0].text | Should -Match 'internal error'
    }
}
