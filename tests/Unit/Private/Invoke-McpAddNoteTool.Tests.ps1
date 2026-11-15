BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/PSMcpKnowledgeBase.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'PSMcpKnowledgeBase'
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
        InModuleScope PSMcpKnowledgeBase -Parameters @{ Context = $script:WriteContext } {
            param($Context)
            { Invoke-McpAddNoteTool -Context $Context -Arguments ([ordered]@{ title = ('t' * 201); content = 'x' }) } | Should -Throw '*200 characters*'
        }
    }

    It 'rejects too many or too long tags, which the size limits do not count' {
        InModuleScope PSMcpKnowledgeBase -Parameters @{ Context = $script:WriteContext } {
            param($Context)
            { Invoke-McpAddNoteTool -Context $Context -Arguments ([ordered]@{ title = 'Tags'; content = 'x'; tags = [string[]](1..21) }) } | Should -Throw '*at most 20 tags*'
            { Invoke-McpAddNoteTool -Context $Context -Arguments ([ordered]@{ title = 'Tags'; content = 'x'; tags = @('t' * 51) }) } | Should -Throw '*50 characters*'
        }
    }

    Context 'limits against agents that fill the knowledge base' {
        BeforeEach {
            New-McpKnowledgeBase -Name Notes | Out-Null
            $script:NotesContext = New-McpTestContext -KnowledgeBase Notes -AllowWrite
        }

        AfterEach {
            Remove-McpKnowledgeBase -Name Notes -Confirm:$false
            InModuleScope PSMcpKnowledgeBase {
                $script:McpMaxAgentNotes = 1000
                $script:McpMaxAgentNoteChars = 10000000
                $script:McpMaxNotesPerMinute = 30
            }
        }

        It 'rejects new notes beyond the maximum number of agent notes but still updates existing ones' {
            InModuleScope PSMcpKnowledgeBase -Parameters @{ Context = $script:NotesContext } {
                param($Context)
                $script:McpMaxAgentNotes = 2
                $null = Invoke-McpAddNoteTool -Context $Context -Arguments ([ordered]@{ title = 'One'; content = 'first' })
                $null = Invoke-McpAddNoteTool -Context $Context -Arguments ([ordered]@{ title = 'Two'; content = 'second' })
                { Invoke-McpAddNoteTool -Context $Context -Arguments ([ordered]@{ title = 'Three'; content = 'third' }) } | Should -Throw '*maximum of 2 agent notes*'
                (Invoke-McpAddNoteTool -Context $Context -Arguments ([ordered]@{ title = 'Two'; content = 'second, revised' })).structuredContent.changed | Should -BeTrue
            }
        }

        It 'does not count documents added by people towards the agent note limits' {
            Add-McpDocument -KnowledgeBase Notes -Title 'Manual' -Content ('x' * 500) | Out-Null
            InModuleScope PSMcpKnowledgeBase -Parameters @{ Context = $script:NotesContext } {
                param($Context)
                $script:McpMaxAgentNotes = 1
                $script:McpMaxAgentNoteChars = 100
                (Invoke-McpAddNoteTool -Context $Context -Arguments ([ordered]@{ title = 'Agent'; content = 'short' })).structuredContent.created | Should -BeTrue
            }
        }

        It 'rejects notes that would exceed the total size of all agent notes' {
            InModuleScope PSMcpKnowledgeBase -Parameters @{ Context = $script:NotesContext } {
                param($Context)
                $script:McpMaxAgentNoteChars = 100
                $null = Invoke-McpAddNoteTool -Context $Context -Arguments ([ordered]@{ title = 'Big'; content = ('a' * 60) })
                { Invoke-McpAddNoteTool -Context $Context -Arguments ([ordered]@{ title = 'Bigger'; content = ('b' * 60) }) } | Should -Throw '*100 characters*'
                # Replacing a note only counts its new size.
                (Invoke-McpAddNoteTool -Context $Context -Arguments ([ordered]@{ title = 'Big'; content = ('c' * 90) })).structuredContent.changed | Should -BeTrue
            }
        }

        It 'limits the number of notes written per minute' {
            InModuleScope PSMcpKnowledgeBase -Parameters @{ Context = $script:NotesContext } {
                param($Context)
                $script:McpMaxNotesPerMinute = 2
                $null = Invoke-McpAddNoteTool -Context $Context -Arguments ([ordered]@{ title = 'A'; content = 'a' })
                $null = Invoke-McpAddNoteTool -Context $Context -Arguments ([ordered]@{ title = 'A'; content = 'b' })
                { Invoke-McpAddNoteTool -Context $Context -Arguments ([ordered]@{ title = 'A'; content = 'c' }) } | Should -Throw '*2 notes per minute*'
                # Writes older than a minute no longer count.
                $Context.NoteWriteTimes.Clear()
                $Context.NoteWriteTimes.Enqueue([datetime]::UtcNow.AddMinutes(-2))
                $Context.NoteWriteTimes.Enqueue([datetime]::UtcNow.AddMinutes(-2))
                (Invoke-McpAddNoteTool -Context $Context -Arguments ([ordered]@{ title = 'A'; content = 'd' })).structuredContent.changed | Should -BeTrue
            }
        }

        It 'reports limit errors to the model as tool errors' {
            InModuleScope PSMcpKnowledgeBase { $script:McpMaxAgentNotes = 0 }
            $call = @{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = @{ name = 'add_note'; arguments = @{ title = 'Blocked'; content = 'x' } } }
            $result = (Invoke-McpTestMessage -KnowledgeBase Notes -AllowWrite -Message $call).result
            $result.isError | Should -BeTrue
            $result.content[0].text | Should -BeLike '*maximum of 0 agent notes*'
        }
    }
}
