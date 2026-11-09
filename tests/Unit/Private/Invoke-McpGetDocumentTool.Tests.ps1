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

Describe 'Invoke-McpGetDocumentTool' {
    It 'reads documents in pages' {
        $doc = Get-McpDocument -KnowledgeBase Proto -Title Onboarding
        $first = (Invoke-McpTestMessage -KnowledgeBase Proto -Message @{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = @{ name = 'get_document'; arguments = @{ id = $doc.Id; maxChars = 500 } } }).result
        $first.structuredContent.truncated | Should -BeTrue
        $first.structuredContent.length | Should -Be 500
        $first.content[0].text | Should -Match 'offset=500'
        $rest = (Invoke-McpTestMessage -KnowledgeBase Proto -Message @{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = @{ name = 'get_document'; arguments = @{ id = $doc.Id; offset = 500; maxChars = 100000 } } }).result
        $rest.structuredContent.truncated | Should -BeFalse
        ($first.structuredContent.content + $rest.structuredContent.content) | Should -Be (Get-McpDocument -KnowledgeBase Proto -Id $doc.Id -IncludeContent).Content
    }

    It 'reports unknown ids as tool errors' {
        $result = (Invoke-McpTestMessage -KnowledgeBase Proto -Message @{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = @{ name = 'get_document'; arguments = @{ id = 'missing' } } }).result
        $result.isError | Should -BeTrue
        $result.content[0].text | Should -Match 'was not found'
    }
}
