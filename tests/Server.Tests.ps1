BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:TestHome = Initialize-McpTestEnvironment -Name server
    New-McpKnowledgeBase -Name Srv -Description 'Servertests' | Out-Null
    Add-McpDocument -KnowledgeBase Srv -Title 'Drucker' -Content "# Drucker`n`nDer Drucker im Flur heißt PRN-01 und wird per IPP angesprochen." | Out-Null
    $script:Pwsh = InModuleScope MCPPosh { Get-McpPwshPath }
}

AfterAll {
    Stop-McpServer -All -Confirm:$false -ErrorAction SilentlyContinue
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'stdio transport' {
    It 'answers a full MCP session via Test-McpServer' {
        $result = Test-McpServer -KnowledgeBase Srv -Query 'Drucker IPP'
        $result.Error | Should -BeNullOrEmpty
        $result.Success | Should -BeTrue
        $result.Tools | Should -Contain 'search_documentation'
        $result.Documents | Should -Be 1
        $result.SearchResults | Should -BeGreaterThan 0
        $result.TopResult | Should -Be 'Drucker'
    }

    It 'writes nothing but JSON-RPC to stdout' {
        $manifest = (Get-Module MCPPosh).Path -replace 'psm1$', 'psd1'
        $command = "Import-Module '$manifest'; Start-McpServer -KnowledgeBase Srv -Transport Stdio"
        $messages = @(
            '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"t","version":"1"}}}'
            '{"jsonrpc":"2.0","method":"notifications/initialized"}'
            '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"search_documentation","arguments":{"query":"Drücker Flur äöü"}}}'
            '{"jsonrpc":"2.0","id":3,"method":"ping"}'
        )
        $output = $messages | & $script:Pwsh -NoProfile -NonInteractive -Command $command 2>$null
        $lines = @($output | Where-Object { $_ -ne '' })
        $lines.Count | Should -Be 3
        foreach ($line in $lines) {
            { $line | ConvertFrom-Json } | Should -Not -Throw
        }
        ($lines[1] | ConvertFrom-Json).result.content[0].text | Should -Match 'PRN-01'
    }

    It 'logs to the knowledge base log file' {
        (Get-McpServerLog -KnowledgeBase Srv -Stdio -Tail 50) -join "`n" | Should -Match 'stdio server started'
    }
}

Describe 'HTTP transport (background server)' {
    BeforeAll {
        $script:Port = InModuleScope MCPPosh { Get-McpFreePort }
        $script:Key = 'test-key-' + [guid]::NewGuid().ToString('N')
        $script:Server = Start-McpServer -KnowledgeBase Srv -Port $script:Port -ApiKey $script:Key -AllowWrite
        $script:Base = "http://localhost:$($script:Port)"
        $script:Auth = @{ Authorization = "Bearer $($script:Key)" }
        $script:Init = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"t","version":"1"}}}'
    }

    AfterAll {
        Stop-McpServer -Port $script:Port -Confirm:$false -ErrorAction SilentlyContinue
    }

    It 'starts in the background and is listed by Get-McpServer' {
        $script:Server.Status | Should -Be 'Running'
        $script:Server.Url | Should -Be "$($script:Base)/mcp"
        $listed = Get-McpServer -KnowledgeBase Srv
        $listed.Port | Should -Be $script:Port
        $listed.AuthRequired | Should -BeTrue
        $listed.AllowWrite | Should -BeTrue
        $listed.ProcessId | Should -Not -Be $PID
    }

    It 'refuses to start a second server on the same port' {
        { Start-McpServer -KnowledgeBase Srv -Port $script:Port -ApiKey x } | Should -Throw '*already running*'
    }

    It 'requires the API key on /mcp' {
        $response = Invoke-WebRequest -Uri "$($script:Base)/mcp" -Method Post -Body $script:Init -ContentType 'application/json' -SkipHttpErrorCheck
        $response.StatusCode | Should -Be 401
        $response.Headers['WWW-Authenticate'] | Should -Match 'Bearer'

        $wrong = Invoke-WebRequest -Uri "$($script:Base)/mcp" -Method Post -Body $script:Init -ContentType 'application/json' -Headers @{ Authorization = 'Bearer wrong' } -SkipHttpErrorCheck
        $wrong.StatusCode | Should -Be 401
    }

    It 'accepts the API key as Bearer token or X-API-Key header' {
        $bearer = Invoke-RestMethod -Uri "$($script:Base)/mcp" -Method Post -Body $script:Init -ContentType 'application/json' -Headers $script:Auth
        $bearer.result.serverInfo.name | Should -Be 'MCPPosh'
        $apiKey = Invoke-RestMethod -Uri "$($script:Base)/mcp" -Method Post -Body $script:Init -ContentType 'application/json' -Headers @{ 'X-API-Key' = $script:Key }
        $apiKey.result.protocolVersion | Should -Be '2025-06-18'
    }

    It 'answers notifications with 202 and GET with 405' {
        $notification = Invoke-WebRequest -Uri "$($script:Base)/mcp" -Method Post -Body '{"jsonrpc":"2.0","method":"notifications/initialized"}' -ContentType 'application/json' -Headers $script:Auth -SkipHttpErrorCheck
        $notification.StatusCode | Should -Be 202
        $get = Invoke-WebRequest -Uri "$($script:Base)/mcp" -Headers $script:Auth -SkipHttpErrorCheck
        $get.StatusCode | Should -Be 405
    }

    It 'rejects foreign origins and unsupported protocol versions' {
        $origin = Invoke-WebRequest -Uri "$($script:Base)/mcp" -Method Post -Body $script:Init -ContentType 'application/json' -Headers ($script:Auth + @{ Origin = 'https://evil.example.com' }) -SkipHttpErrorCheck
        $origin.StatusCode | Should -Be 403
        $localOrigin = Invoke-WebRequest -Uri "$($script:Base)/mcp" -Method Post -Body $script:Init -ContentType 'application/json' -Headers ($script:Auth + @{ Origin = 'http://localhost:3000' }) -SkipHttpErrorCheck
        $localOrigin.StatusCode | Should -Be 200
        $version = Invoke-WebRequest -Uri "$($script:Base)/mcp" -Method Post -Body $script:Init -ContentType 'application/json' -Headers ($script:Auth + @{ 'MCP-Protocol-Version' = '1999-01-01' }) -SkipHttpErrorCheck
        $version.StatusCode | Should -Be 400
    }

    It 'shows health details only to authorized callers' {
        $anonymous = Invoke-RestMethod -Uri "$($script:Base)/health"
        $anonymous.status | Should -Be 'ok'
        $anonymous.PSObject.Properties.Name | Should -Not -Contain 'documents'
        $authorized = Invoke-RestMethod -Uri "$($script:Base)/health" -Headers $script:Auth
        $authorized.knowledgeBase | Should -Be 'Srv'
        $authorized.documents | Should -BeGreaterOrEqual 1

        $remote = Get-McpServer -Uri "$($script:Base)/mcp" -ApiKey $script:Key
        $remote.Status | Should -Be 'Running'
        $remote.KnowledgeBase | Should -Be 'Srv'
    }

    It 'passes Test-McpServer and supports add_note' {
        $result = Test-McpServer -Uri $script:Base -ApiKey $script:Key -Query 'PRN-01'
        $result.Error | Should -BeNullOrEmpty
        $result.Success | Should -BeTrue
        $result.Tools | Should -Contain 'add_note'
        (Test-McpServer -Uri $script:Base).Error | Should -Match '401'
    }

    It 'serves documents added while it is running' {
        $body = '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"search_documentation","arguments":{"query":"Kantine Speiseplan"}}}'
        (Invoke-RestMethod -Uri "$($script:Base)/mcp" -Method Post -Body $body -ContentType 'application/json' -Headers $script:Auth).result.structuredContent.results | Should -BeNullOrEmpty
        Add-McpDocument -KnowledgeBase Srv -Title 'Kantine' -Content 'Der Speiseplan der Kantine hängt am Eingang.' | Out-Null
        Start-Sleep -Milliseconds 1200
        $results = (Invoke-RestMethod -Uri "$($script:Base)/mcp" -Method Post -Body $body -ContentType 'application/json' -Headers $script:Auth).result.structuredContent.results
        $results[0].title | Should -Be 'Kantine'
    }

    It 'writes a log file' {
        (Get-McpServerLog -KnowledgeBase Srv -Port $script:Port -Tail 100) -join "`n" | Should -Match 'listening on'
    }

    It 'restarts with the same settings' {
        $restarted = Restart-McpServer -Port $script:Port -ApiKey $script:Key
        $restarted.Status | Should -Be 'Running'
        $restarted.ProcessId | Should -Not -Be $script:Server.ProcessId
        $restarted.AllowWrite | Should -BeTrue
        { Restart-McpServer -Port $script:Port -ErrorAction Stop } | Should -Throw '*API key*'
    }

    It 'stops the server' {
        Stop-McpServer -Port $script:Port -Confirm:$false
        Get-McpServer -Port $script:Port | Should -BeNullOrEmpty
        { Invoke-WebRequest -Uri "$($script:Base)/health" -TimeoutSec 2 } | Should -Throw
    }
}

Describe 'Start-McpServer safety checks' {
    It 'requires an API key when listening on all interfaces' {
        $previous = $env:MCPPOSH_API_KEY
        $env:MCPPOSH_API_KEY = $null
        try {
            { Start-McpServer -KnowledgeBase Srv -ListenAddress '*' -Port 5999 } | Should -Throw '*ApiKey*'
        }
        finally {
            $env:MCPPOSH_API_KEY = $previous
        }
    }
}

Describe 'Get-McpClientConfig' {
    It 'creates a stdio configuration for Claude Desktop' {
        $config = Get-McpClientConfig -KnowledgeBase Srv -Client ClaudeDesktop
        $json = $config.Json | ConvertFrom-Json
        $entry = $json.mcpServers.'mcpposh-srv'
        $entry.command | Should -Be $script:Pwsh
        $entry.args | Should -Contain '-NoProfile'
        $entry.args[-1] | Should -Match "Start-McpServer -KnowledgeBase 'Srv' -Transport Stdio"
        $entry.env.MCPPOSH_HOME | Should -Be $env:MCPPOSH_HOME
        $config.ConfigFile | Should -Match 'claude_desktop_config.json'
    }

    It 'creates a claude mcp add command for Claude Code' {
        $config = Get-McpClientConfig -KnowledgeBase Srv -Client ClaudeCode -AllowWrite
        $config.Command | Should -Match '^claude mcp add .*mcpposh-srv -- '
        $config.Command | Should -Match '-AllowWrite'
        ($config.Json | ConvertFrom-Json).mcpServers.'mcpposh-srv'.type | Should -Be 'stdio'
    }

    It 'creates an HTTP configuration for VS Code with a key prompt' {
        $json = Get-McpClientConfig -KnowledgeBase Srv -Client VSCode -Transport Http -Uri 'https://docs.example.com' -ApiKeyPlaceholder -AsJson | ConvertFrom-Json
        $json.servers.'mcpposh-srv'.type | Should -Be 'http'
        $json.servers.'mcpposh-srv'.url | Should -Be 'https://docs.example.com/mcp'
        $json.servers.'mcpposh-srv'.headers.Authorization | Should -Be 'Bearer ${input:mcpposh-api-key}'
        $json.inputs[0].password | Should -BeTrue
    }

    It 'creates an HTTP configuration for Cursor and Claude Code' {
        $cursor = Get-McpClientConfig -KnowledgeBase Srv -Client Cursor -Transport Http -Uri 'https://docs.example.com/mcp' -ApiKey 'abc' -AsJson | ConvertFrom-Json
        $cursor.mcpServers.'mcpposh-srv'.headers.Authorization | Should -Be 'Bearer abc'
        $code = Get-McpClientConfig -KnowledgeBase Srv -Client ClaudeCode -Transport Http -Uri 'https://docs.example.com/mcp' -ApiKey 'abc'
        $code.Command | Should -Match '^claude mcp add --transport http mcpposh-srv https://docs.example.com/mcp --header'
    }

    It 'uses mcp-remote for Claude Desktop over HTTP' {
        $json = Get-McpClientConfig -KnowledgeBase Srv -Client ClaudeDesktop -Transport Http -Uri 'https://docs.example.com/mcp' -ApiKey 'abc' -AsJson | ConvertFrom-Json
        $json.mcpServers.'mcpposh-srv'.command | Should -Be 'npx'
        $json.mcpServers.'mcpposh-srv'.args | Should -Contain 'mcp-remote'
    }

    It 'requires a running server or -Uri for HTTP' {
        { Get-McpClientConfig -KnowledgeBase Srv -Transport Http } | Should -Throw '*No running HTTP server*'
    }
}
