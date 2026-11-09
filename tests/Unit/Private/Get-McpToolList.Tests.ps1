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

Describe 'Get-McpToolList' {
    It 'lists the read-only tools by default' {
        $tools = (Invoke-McpTestMessage -KnowledgeBase Proto -Message @{ jsonrpc = '2.0'; id = 1; method = 'tools/list' }).result.tools
        $tools.name | Should -Be @('search_documentation', 'get_document', 'list_documents')
        ($tools | Where-Object name -EQ 'search_documentation').inputSchema.required | Should -Be @('query')
        ($tools | Where-Object name -EQ 'search_documentation').annotations.readOnlyHint | Should -BeTrue
        ($tools | Where-Object name -EQ 'search_documentation').description | Should -Match 'Protocol tests'
    }

    It 'adds add_note with write access' {
        (Invoke-McpTestMessage -KnowledgeBase Proto -AllowWrite -Message @{ jsonrpc = '2.0'; id = 1; method = 'tools/list' }).result.tools.name | Should -Contain 'add_note'
    }
}
