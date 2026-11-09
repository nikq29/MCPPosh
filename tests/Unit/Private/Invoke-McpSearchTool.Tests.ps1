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

Describe 'Invoke-McpSearchTool' {
    It 'returns matching sections with structured content' {
        $result = (Invoke-McpTestMessage -KnowledgeBase Proto -Message @{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = @{ name = 'search_documentation'; arguments = @{ query = 'When does the backup run?' } } }).result
        $result.content[0].text | Should -Match 'Veeam'
        $result.content[0].text | Should -Match '## 1\. Backup'
        $result.structuredContent.results[0].title | Should -Be 'Backup'
        $result.structuredContent.results[0].uri | Should -Match '^mcpposh://Proto/documents/backup-'
    }

    It 'explains when nothing was found' {
        $result = (Invoke-McpTestMessage -KnowledgeBase Proto -Message @{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = @{ name = 'search_documentation'; arguments = @{ query = 'backup'; tags = @('hr') } } }).result
        $result.content[0].text | Should -Match 'No matching sections'
        @($result.structuredContent.results).Count | Should -Be 0
    }
}
