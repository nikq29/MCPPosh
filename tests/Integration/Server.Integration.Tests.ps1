BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment -Name integration
    New-McpKnowledgeBase -Name Srv -Description 'Integration tests' | Out-Null
    Add-McpDocument -KnowledgeBase Srv -Title 'Printer' -Content "# Printer`n`nThe hallway printer is PRN-01 and uses IPP." | Out-Null
    $script:Pwsh = & (Get-Module MCPPosh) { Get-McpPwshPath }
    $script:Manifest = & (Get-Module MCPPosh) { $script:ModuleManifestPath }
}

AfterAll {
    Stop-McpServer -All -Confirm:$false -ErrorAction SilentlyContinue
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'stdio transport (real process)' {
    It 'writes nothing but JSON-RPC to stdout' {
        $command = "Import-Module '$($script:Manifest)'; Start-McpServer -KnowledgeBase Srv -Transport Stdio"
        $messages = @(
            '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"t","version":"1"}}}'
            '{"jsonrpc":"2.0","method":"notifications/initialized"}'
            '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"search_documentation","arguments":{"query":"printer hallway"}}}'
            '{"jsonrpc":"2.0","id":3,"method":"ping"}'
        )
        $output = $messages | & $script:Pwsh -NoProfile -NonInteractive -Command $command 2>$null
        $lines = @($output | Where-Object { $_ -ne '' })
        $lines.Count | Should -Be 3
        foreach ($line in $lines) { { $line | ConvertFrom-Json } | Should -Not -Throw }
        ($lines[1] | ConvertFrom-Json).result.content[0].text | Should -Match 'PRN-01'
    }

    It 'logs to the knowledge base log file' {
        (Get-McpServerLog -KnowledgeBase Srv -Stdio -Tail 50) -join "`n" | Should -Match 'stdio server started'
    }
}

Describe 'HTTP transport (background process)' {
    BeforeAll {
        $script:Port = & (Get-Module MCPPosh) { Get-McpFreePort }
        $script:Key = 'test-key-' + [guid]::NewGuid().ToString('N')
        $script:Server = Start-McpServer -KnowledgeBase Srv -Port $script:Port -ApiKey $script:Key -AllowWrite
        $script:Base = "http://localhost:$($script:Port)"
        $script:Auth = @{ Authorization = "Bearer $($script:Key)" }
        $script:Init = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"t","version":"1"}}}'
    }

    AfterAll {
        Stop-McpServer -Port $script:Port -Confirm:$false -ErrorAction SilentlyContinue
    }

    It 'runs in a separate process and is listed by Get-McpServer' {
        $script:Server.Status | Should -Be 'Running'
        $script:Server.ProcessId | Should -Not -Be $PID
        (Get-McpServer -KnowledgeBase Srv).Port | Should -Be $script:Port
    }

    It 'requires the API key and accepts Bearer and X-API-Key' {
        (Invoke-WebRequest -Uri "$($script:Base)/mcp" -Method Post -Body $script:Init -ContentType 'application/json' -SkipHttpErrorCheck).StatusCode | Should -Be 401
        (Invoke-RestMethod -Uri "$($script:Base)/mcp" -Method Post -Body $script:Init -ContentType 'application/json' -Headers $script:Auth).result.serverInfo.name | Should -Be 'MCPPosh'
        (Invoke-RestMethod -Uri "$($script:Base)/mcp" -Method Post -Body $script:Init -ContentType 'application/json' -Headers @{ 'X-API-Key' = $script:Key }).result.protocolVersion | Should -Be '2025-06-18'
    }

    It 'answers notifications with 202, GET with 405 and rejects foreign origins' {
        (Invoke-WebRequest -Uri "$($script:Base)/mcp" -Method Post -Body '{"jsonrpc":"2.0","method":"notifications/initialized"}' -ContentType 'application/json' -Headers $script:Auth -SkipHttpErrorCheck).StatusCode | Should -Be 202
        (Invoke-WebRequest -Uri "$($script:Base)/mcp" -Headers $script:Auth -SkipHttpErrorCheck).StatusCode | Should -Be 405
        (Invoke-WebRequest -Uri "$($script:Base)/mcp" -Method Post -Body $script:Init -ContentType 'application/json' -Headers ($script:Auth + @{ Origin = 'https://evil.example.com' }) -SkipHttpErrorCheck).StatusCode | Should -Be 403
    }

    It 'shows health details only to authorized callers' {
        (Invoke-RestMethod -Uri "$($script:Base)/health").PSObject.Properties.Name | Should -Not -Contain 'documents'
        (Invoke-RestMethod -Uri "$($script:Base)/health" -Headers $script:Auth).knowledgeBase | Should -Be 'Srv'
    }

    It 'passes Test-McpServer and serves documents added while running' {
        (Test-McpServer -Uri $script:Base -ApiKey $script:Key -Query 'PRN-01').Success | Should -BeTrue
        Add-McpDocument -KnowledgeBase Srv -Title 'Canteen' -Content 'The canteen menu hangs at the entrance.' | Out-Null
        Start-Sleep -Milliseconds 1200
        (Test-McpServer -Uri $script:Base -ApiKey $script:Key -Query 'canteen menu').TopResult | Should -Be 'Canteen'
    }

    It 'restarts with the same settings and stops' {
        $restarted = Restart-McpServer -Port $script:Port -ApiKey $script:Key
        $restarted.Status | Should -Be 'Running'
        $restarted.ProcessId | Should -Not -Be $script:Server.ProcessId
        $restarted.AllowWrite | Should -BeTrue
        Stop-McpServer -Port $script:Port -Confirm:$false
        Get-McpServer -Port $script:Port | Should -BeNullOrEmpty
    }
}
