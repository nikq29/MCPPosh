BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:TestHome = Initialize-McpTestEnvironment -Name protocol
    New-McpKnowledgeBase -Name Proto -Description 'Protokolltests' | Out-Null
    Add-McpDocument -KnowledgeBase Proto -Title 'Backup' -Content "# Backup`n`nDas nächtliche Backup läuft um 02:00 Uhr mit Veeam." -Tags ops | Out-Null
    Add-McpDocument -KnowledgeBase Proto -Title 'Onboarding' -Content ("# Onboarding`n`n" + ('Neue Mitarbeitende erhalten ihren Laptop am ersten Tag. ' * 40)) -Tags hr | Out-Null

    function Invoke-TestRpc {
        param([object] $Message, [switch] $AllowWrite)
        $json = if ($Message -is [string]) { $Message } else { $Message | ConvertTo-Json -Depth 20 -Compress }
        InModuleScope MCPPosh -Parameters @{ Json = $json; AllowWrite = [bool]$AllowWrite } {
            param($Json, $AllowWrite)
            $kb = Resolve-McpKnowledgeBase -KnowledgeBase Proto
            $context = New-McpServerContext -KnowledgeBase $kb -AllowWrite:$AllowWrite -LogPath (Join-Path $kb.Path 'logs/test.log')
            $response = Invoke-McpMessage -Context $context -Json $Json
            if ($null -ne $response) { $response | ConvertFrom-Json -Depth 50 }
        }
    }
}

AfterAll {
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'JSON-RPC handling' {
    It 'returns a parse error for invalid JSON' {
        $response = Invoke-TestRpc -Message '{not json'
        $response.error.code | Should -Be -32700
        $response.id | Should -BeNullOrEmpty
    }

    It 'rejects requests without jsonrpc 2.0' {
        (Invoke-TestRpc -Message @{ id = 1; method = 'ping' }).error.code | Should -Be -32600
    }

    It 'returns method not found for unknown methods' {
        (Invoke-TestRpc -Message @{ jsonrpc = '2.0'; id = 1; method = 'does/not/exist' }).error.code | Should -Be -32601
    }

    It 'does not answer notifications' {
        Invoke-TestRpc -Message @{ jsonrpc = '2.0'; method = 'notifications/initialized' } | Should -BeNullOrEmpty
    }

    It 'preserves string and numeric ids' {
        (Invoke-TestRpc -Message '{"jsonrpc":"2.0","id":"abc-1","method":"ping"}').id | Should -Be 'abc-1'
        $numeric = Invoke-TestRpc -Message '{"jsonrpc":"2.0","id":42,"method":"ping"}'
        $numeric.id | Should -Be 42
        $numeric.id | Should -BeOfType [long]
    }

    It 'keeps date-like strings unchanged' {
        $response = Invoke-TestRpc -Message @{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = @{ name = 'search_documentation'; arguments = @{ query = '2025-06-18' } } }
        $response.result.content[0].text | Should -Match '"2025-06-18"'
    }

    It 'processes batches and omits notification responses' {
        $response = Invoke-TestRpc -Message '[{"jsonrpc":"2.0","id":1,"method":"ping"},{"jsonrpc":"2.0","method":"notifications/initialized"},{"jsonrpc":"2.0","id":2,"method":"ping"}]'
        @($response).Count | Should -Be 2
        $response.id | Should -Be @(1, 2)
    }
}

Describe 'initialize' {
    It 'negotiates a supported protocol version' {
        $response = Invoke-TestRpc -Message @{ jsonrpc = '2.0'; id = 1; method = 'initialize'; params = @{ protocolVersion = '2025-03-26'; capabilities = @{}; clientInfo = @{ name = 'pester'; version = '1' } } }
        $response.result.protocolVersion | Should -Be '2025-03-26'
    }

    It 'falls back to the latest version for unknown versions' {
        $response = Invoke-TestRpc -Message @{ jsonrpc = '2.0'; id = 1; method = 'initialize'; params = @{ protocolVersion = '1999-01-01' } }
        $response.result.protocolVersion | Should -Be '2025-11-25'
    }

    It 'announces tools and resources and includes the knowledge base description as instructions' {
        $result = (Invoke-TestRpc -Message @{ jsonrpc = '2.0'; id = 1; method = 'initialize'; params = @{ protocolVersion = '2025-06-18' } }).result
        $result.capabilities.tools | Should -Not -BeNullOrEmpty
        $result.capabilities.resources | Should -Not -BeNullOrEmpty
        $result.serverInfo.name | Should -Be 'MCPPosh'
        $result.instructions | Should -Match 'Protokolltests'
        $result.instructions | Should -Not -Match 'add_note'
    }
}

Describe 'tools' {
    It 'lists the read-only tools by default' {
        $tools = (Invoke-TestRpc -Message @{ jsonrpc = '2.0'; id = 1; method = 'tools/list' }).result.tools
        $tools.name | Should -Be @('search_documentation', 'get_document', 'list_documents')
        ($tools | Where-Object name -EQ 'search_documentation').inputSchema.required | Should -Be @('query')
        ($tools | Where-Object name -EQ 'search_documentation').annotations.readOnlyHint | Should -BeTrue
    }

    It 'adds add_note only when write access is enabled' {
        $tools = (Invoke-TestRpc -Message @{ jsonrpc = '2.0'; id = 1; method = 'tools/list' } -AllowWrite).result.tools
        $tools.name | Should -Contain 'add_note'
        $denied = Invoke-TestRpc -Message @{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = @{ name = 'add_note'; arguments = @{ title = 'x'; content = 'y' } } }
        $denied.error.code | Should -Be -32602
    }

    It 'searches the documentation' {
        $result = (Invoke-TestRpc -Message @{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = @{ name = 'search_documentation'; arguments = @{ query = 'Wann läuft das Backup?' } } }).result
        $result.isError | Should -BeNullOrEmpty
        $result.content[0].type | Should -Be 'text'
        $result.content[0].text | Should -Match 'Veeam'
        $result.structuredContent.results[0].title | Should -Be 'Backup'
        $result.structuredContent.results[0].uri | Should -Match '^mcpposh://Proto/documents/backup-'
    }

    It 'filters searches by tag' {
        $result = (Invoke-TestRpc -Message @{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = @{ name = 'search_documentation'; arguments = @{ query = 'Backup'; tags = @('hr') } } }).result
        $result.structuredContent.results | Should -BeNullOrEmpty
        $result.content[0].text | Should -Match 'No matching sections'
    }

    It 'reports invalid arguments as tool errors' {
        $result = (Invoke-TestRpc -Message @{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = @{ name = 'search_documentation'; arguments = @{ limit = 3 } } }).result
        $result.isError | Should -BeTrue
        $result.content[0].text | Should -Match "query"

        $result = (Invoke-TestRpc -Message @{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = @{ name = 'search_documentation'; arguments = @{ query = 'x'; limit = 500 } } }).result
        $result.isError | Should -BeTrue
    }

    It 'returns protocol errors for unknown tools' {
        (Invoke-TestRpc -Message @{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = @{ name = 'nope' } }).error.code | Should -Be -32602
    }

    It 'reads documents in pages' {
        $doc = Get-McpDocument -KnowledgeBase Proto -Title Onboarding
        $first = (Invoke-TestRpc -Message @{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = @{ name = 'get_document'; arguments = @{ id = $doc.Id; maxChars = 500 } } }).result
        $first.structuredContent.truncated | Should -BeTrue
        $first.structuredContent.length | Should -Be 500
        $first.content[0].text | Should -Match 'offset=500'

        $rest = (Invoke-TestRpc -Message @{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = @{ name = 'get_document'; arguments = @{ id = $doc.Id; offset = 500; maxChars = 100000 } } }).result
        $rest.structuredContent.truncated | Should -BeFalse
        ($first.structuredContent.content + $rest.structuredContent.content) | Should -Be (Get-McpDocument -KnowledgeBase Proto -Id $doc.Id -IncludeContent).Content
    }

    It 'reports unknown document ids as tool errors' {
        $result = (Invoke-TestRpc -Message @{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = @{ name = 'get_document'; arguments = @{ id = 'missing' } } }).result
        $result.isError | Should -BeTrue
    }

    It 'lists documents with tag filter and paging' {
        $all = (Invoke-TestRpc -Message @{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = @{ name = 'list_documents'; arguments = @{} } }).result
        $all.structuredContent.total | Should -Be 2
        $ops = (Invoke-TestRpc -Message @{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = @{ name = 'list_documents'; arguments = @{ tag = 'ops' } } }).result
        $ops.structuredContent.documents.title | Should -Be 'Backup'
        $page = (Invoke-TestRpc -Message @{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = @{ name = 'list_documents'; arguments = @{ limit = 1 } } }).result
        $page.content[0].text | Should -Match 'offset=1'
    }

    It 'stores agent notes with add_note and updates notes with the same title' {
        $call = @{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = @{ name = 'add_note'; arguments = @{ title = 'Erkenntnis'; content = 'Der Drucker im 3. OG braucht Treiber v2.'; tags = @('it') } } }
        $first = (Invoke-TestRpc -Message $call -AllowWrite).result
        $first.structuredContent.created | Should -BeTrue
        $call.params.arguments.content = 'Der Drucker im 3. OG braucht Treiber v3.'
        $second = (Invoke-TestRpc -Message $call -AllowWrite).result
        $second.structuredContent.id | Should -Be $first.structuredContent.id
        $second.structuredContent.created | Should -BeFalse

        $note = Get-McpDocument -KnowledgeBase Proto -SourceType Agent -IncludeContent
        $note.Title | Should -Be 'Erkenntnis'
        $note.Tags | Should -Be @('agent-note', 'it')
        $note.Content | Should -Match 'v3'
    }
}

Describe 'resources' {
    It 'lists documents as resources' {
        $resources = (Invoke-TestRpc -Message @{ jsonrpc = '2.0'; id = 1; method = 'resources/list' }).result.resources
        $resources.Count | Should -BeGreaterOrEqual 2
        $resources[0].uri | Should -Match '^mcpposh://Proto/documents/'
        $resources[0].mimeType | Should -Be 'text/markdown'
    }

    It 'reads a resource' {
        $doc = Get-McpDocument -KnowledgeBase Proto -Title Backup
        $contents = (Invoke-TestRpc -Message @{ jsonrpc = '2.0'; id = 1; method = 'resources/read'; params = @{ uri = $doc.Uri } }).result.contents
        $contents[0].text | Should -Match 'Veeam'
    }

    It 'returns resource not found for unknown URIs' {
        (Invoke-TestRpc -Message @{ jsonrpc = '2.0'; id = 1; method = 'resources/read'; params = @{ uri = 'mcpposh://Proto/documents/nope' } }).error.code | Should -Be -32002
        (Invoke-TestRpc -Message @{ jsonrpc = '2.0'; id = 1; method = 'resources/read'; params = @{ uri = 'mcpposh://Other/documents/x' } }).error.code | Should -Be -32002
    }

    It 'provides a resource template' {
        $templates = (Invoke-TestRpc -Message @{ jsonrpc = '2.0'; id = 1; method = 'resources/templates/list' }).result.resourceTemplates
        $templates[0].uriTemplate | Should -Be 'mcpposh://Proto/documents/{id}'
    }
}
