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

Describe 'Invoke-McpAddNoteTool' {
    It 'stores agent notes and updates notes with the same title' {
        $call = @{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = @{ name = 'add_note'; arguments = @{ title = 'Finding'; content = 'The printer needs driver v2.'; tags = @('it') } } }
        $first = (Invoke-McpTestMessage -KnowledgeBase Proto -AllowWrite -Message $call).result
        $first.structuredContent.created | Should -BeTrue
        $call.params.arguments.content = 'The printer needs driver v3.'
        $second = (Invoke-McpTestMessage -KnowledgeBase Proto -AllowWrite -Message $call).result
        $second.structuredContent.id | Should -Be $first.structuredContent.id
        $second.structuredContent.created | Should -BeFalse
        $note = Get-McpDocument -KnowledgeBase Proto -SourceType Agent -IncludeContent
        $note.Tags | Should -Be @('agent-note', 'it')
        $note.Content | Should -Match 'v3'
    }

    It 'rejects titles and contents that are too long' {
        InModuleScope MCPPosh -Parameters @{ Context = $script:WriteContext } {
            param($Context)
            { Invoke-McpAddNoteTool -Context $Context -Arguments ([ordered]@{ title = ('t' * 201); content = 'x' }) } | Should -Throw '*200 characters*'
        }
    }
}
