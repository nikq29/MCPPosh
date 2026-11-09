<#
    End-to-end tests of the server cmdlets against the built module: real stdio and HTTP server processes,
    foreground and background servers, logs, status, restart and stop. No mocks.
#>
BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment -Name integration
    New-McpKnowledgeBase -Name Srv -Description 'Integration tests' | Out-Null
    Add-McpDocument -KnowledgeBase Srv -Title 'Printer' -Content "# Printer`n`nThe hallway printer is PRN-01 and uses IPP." | Out-Null
    $script:Pwsh = & (Get-Module MCPPosh) { Get-McpPwshPath }
    $script:Manifest = & (Get-Module MCPPosh) { $script:ModuleManifestPath }
    $script:Init = (Get-McpTestRpcMessage)[0]
}

AfterAll {
    Stop-McpServer -All -Confirm:$false -ErrorAction SilentlyContinue
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'stdio transport (real process)' {
    It 'writes nothing but JSON-RPC to stdout' {
        $encoded = ConvertTo-McpTestEncodedCommand -ArgumentList $script:Manifest -ScriptBlock {
            param($Manifest)
            Import-Module -Name $Manifest
            Start-McpServer -KnowledgeBase Srv -Transport Stdio
        }
        $messages = @(Get-McpTestRpcMessage -ToolCall @{ Name = 'search_documentation'; Arguments = @{ query = 'printer hallway' } }) +
            '{"jsonrpc":"2.0","id":3,"method":"ping"}'
        $session = Invoke-McpTestStdioSession -FilePath $script:Pwsh -ArgumentList '-NoProfile', '-NonInteractive', '-EncodedCommand', $encoded -Message $messages
        $session.Lines.Count | Should -Be 3 -Because $session.StdErr
        $session.Responses[1].result.content[0].text | Should -Match 'PRN-01'
        $session.Responses[2].id | Should -Be 3
    }

    It 'logs to the knowledge base log file' {
        (Get-McpServerLog -KnowledgeBase Srv -Stdio -Tail 50) -join "`n" | Should -Match 'stdio server started'
    }

    It 'passes Test-McpServer through a stdio process' {
        $result = Test-McpServer -KnowledgeBase Srv -Query 'hallway printer' -TimeoutSeconds 60
        $result.Success | Should -BeTrue -Because $result.Error
        $result.Transport | Should -Be 'Stdio'
        $result.Target | Should -Be 'stdio: Srv'
        $result.Tools | Should -Contain 'search_documentation'
        $result.Documents | Should -Be 1
        $result.TopResult | Should -Be 'Printer'
    }
}

Describe 'HTTP transport (background process)' {
    BeforeAll {
        $script:Port = Get-McpTestFreePort
        $script:Key = 'test-key-' + [guid]::NewGuid().ToString('N')
        $script:Server = Start-McpServer -KnowledgeBase Srv -Port $script:Port -ApiKey $script:Key -AllowWrite
        $script:Base = "http://localhost:$($script:Port)"
        $script:Auth = @{ Authorization = "Bearer $($script:Key)" }
    }

    AfterAll {
        Stop-McpServer -Port $script:Port -Confirm:$false -ErrorAction SilentlyContinue
    }

    It 'runs in a separate process and is listed by Get-McpServer' {
        $script:Server.Status | Should -Be 'Running'
        $script:Server.ProcessId | Should -Not -Be $PID
        (Get-McpServer -KnowledgeBase Srv).Port | Should -Be $script:Port
        $local = Get-McpServer -Port $script:Port
        $local.KnowledgeBase | Should -Be 'Srv'
        $local.AuthRequired | Should -BeTrue
        $local.AllowWrite | Should -BeTrue
        $local.Url | Should -Be "$($script:Base)/mcp"
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

    It 'reports the status of a remote server with Get-McpServer -Uri' {
        $remote = Get-McpServer -Uri $script:Base -ApiKey $script:Key
        $remote.Status | Should -Be 'Running'
        $remote.KnowledgeBase | Should -Be 'Srv'
        $remote.Documents | Should -Be 1
        $remote.AuthRequired | Should -BeTrue
        $remote.AllowWrite | Should -BeTrue
        $remote.Url | Should -Be "$($script:Base)/mcp"
        $anonymous = Get-McpServer -Uri "$($script:Base)/mcp"
        $anonymous.Status | Should -Be 'Running'
        $anonymous.Documents | Should -BeNullOrEmpty
    }

    It 'passes Test-McpServer and serves documents added while running' {
        (Test-McpServer -Uri $script:Base -ApiKey $script:Key -Query 'PRN-01' -TimeoutSeconds 60).Success | Should -BeTrue
        Add-McpDocument -KnowledgeBase Srv -Title 'Canteen' -Content 'The canteen menu hangs at the entrance.' | Out-Null
        Start-Sleep -Milliseconds 1200
        (Test-McpServer -Uri $script:Base -ApiKey $script:Key -Query 'canteen menu').TopResult | Should -Be 'Canteen'
    }

    It 'shows the server log by port, the latest log and the last lines' {
        (Get-McpServerLog -KnowledgeBase Srv -Port $script:Port -Tail 500) -join "`n" | Should -Match 'listening on'
        @(Get-McpServerLog -KnowledgeBase Srv -Port $script:Port -Tail 2).Count | Should -Be 2
        (Get-McpServerLog -KnowledgeBase Srv -Tail 500) -join "`n" | Should -Match 'canteen menu'
    }

    It 'follows the log with -Wait' {
        $job = Start-ThreadJob -ArgumentList $script:Manifest, $script:Port -ScriptBlock {
            param($Manifest, $Port)
            Import-Module -Name $Manifest
            Get-McpServerLog -KnowledgeBase Srv -Port ([int]$Port) -Tail 1 -Wait
        }
        try {
            Start-Sleep -Seconds 1
            Test-McpServer -Uri $script:Base -ApiKey $script:Key -Query 'zebra crossing' | Out-Null
            Wait-McpTestCondition -TimeoutSeconds 30 -Because 'the followed log did not show the new request' {
                (@(Receive-Job -Job $job -Keep) -join "`n") -match 'zebra crossing'
            } | Should -BeTrue
        }
        finally {
            $job | Stop-Job -PassThru | Remove-Job -Force
        }
    }

    It 'does not remove a knowledge base that a running server serves' {
        Remove-McpKnowledgeBase -Name Srv -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable removeError
        $removeError | Should -Match 'running MCP server'
        (Get-McpKnowledgeBase -Name Srv).Name | Should -Be 'Srv'
    }

    It 'restarts by knowledge base with the same settings' {
        $before = (Get-McpServer -Port $script:Port).ProcessId
        $restarted = Restart-McpServer -KnowledgeBase Srv -ApiKey $script:Key
        $restarted.Status | Should -Be 'Running'
        $restarted.Port | Should -Be $script:Port
        $restarted.ProcessId | Should -Not -Be $before
        $restarted.AllowWrite | Should -BeTrue
    }

    It 'restarts by port and stops' {
        $before = (Get-McpServer -Port $script:Port).ProcessId
        $restarted = Restart-McpServer -Port $script:Port -ApiKey $script:Key
        $restarted.Status | Should -Be 'Running'
        $restarted.ProcessId | Should -Not -Be $before
        (Test-McpServer -Uri $script:Base -ApiKey $script:Key).Success | Should -BeTrue
        Stop-McpServer -Port $script:Port -Confirm:$false
        Get-McpServer -Port $script:Port | Should -BeNullOrEmpty
    }
}

Describe 'Server options' {
    BeforeAll {
        New-McpKnowledgeBase -Name Web -Description 'Browser clients' | Out-Null
        Add-McpDocument -KnowledgeBase Web -Title 'Intranet' -Content 'The intranet start page is intranet.contoso.example.' | Out-Null
        $script:WebKey = 'web-key-' + [guid]::NewGuid().ToString('N')
    }

    It 'runs in the foreground of its own process with -Foreground, -ListenAddress and -AllowAnonymous' {
        $port = Get-McpTestFreePort
        $output = Join-Path -Path $script:TestHome -ChildPath "foreground-$port.log"
        $process = Start-McpTestProcess -OutputPath $output -ArgumentList $script:Manifest, $env:MCPPOSH_HOME, $port -ScriptBlock {
            param($Manifest, $McpHome, $Port)
            $env:MCPPOSH_HOME = $McpHome
            Import-Module -Name $Manifest
            Start-McpServer -KnowledgeBase Srv -Port ([int]$Port) -ListenAddress 127.0.0.1 -AllowAnonymous -Foreground
        }
        try {
            $server = Wait-McpTestCondition -Because 'the foreground server did not start' {
                Get-McpServer -Port $port | Where-Object Status -EQ 'Running'
            }
            $server.ProcessId | Should -Be $process.Id
            $server.ListenAddress | Should -Be '127.0.0.1'
            $server.AllowAnonymous | Should -BeTrue
            $server.AuthRequired | Should -BeFalse
            (Test-McpServer -Uri "http://localhost:$port" -Query 'hallway printer').TopResult | Should -Be 'Printer'
            # In the foreground the log is also written to the console.
            Wait-McpTestCondition -TimeoutSeconds 15 -Because 'the foreground server did not echo its log' {
                (Get-Content -LiteralPath $output -Raw) -match 'listening on'
            } | Should -BeTrue
        }
        finally {
            Stop-McpServer -Port $port -Confirm:$false -ErrorAction SilentlyContinue
            if (-not $process.WaitForExit(15000)) { $process.Kill($true) }
        }
        $process.HasExited | Should -BeTrue
    }

    It 'accepts browser requests only from allowed origins' {
        $script:WebPort = Get-McpTestFreePort
        $server = Start-McpServer -KnowledgeBase Web -Port $script:WebPort -ApiKey $script:WebKey -AllowedOrigin 'https://docs.contoso.example' -StartTimeoutSeconds 60
        $server.AllowedOrigins | Should -Be @('https://docs.contoso.example')
        $headers = @{ Authorization = "Bearer $($script:WebKey)" }
        $uri = "http://localhost:$($script:WebPort)/mcp"
        (Invoke-WebRequest -Uri $uri -Method Post -Body $script:Init -ContentType 'application/json' -Headers ($headers + @{ Origin = 'https://docs.contoso.example' }) -SkipHttpErrorCheck).StatusCode | Should -Be 200
        (Invoke-WebRequest -Uri $uri -Method Post -Body $script:Init -ContentType 'application/json' -Headers ($headers + @{ Origin = 'https://other.example.com' }) -SkipHttpErrorCheck).StatusCode | Should -Be 403
    }

    It 'refuses to listen on all interfaces without an API key' {
        $savedKey = $env:MCPPOSH_API_KEY
        Remove-Item -Path Env:MCPPOSH_API_KEY -ErrorAction SilentlyContinue
        try {
            { Start-McpServer -KnowledgeBase Web -Port (Get-McpTestFreePort) -ListenAddress 0.0.0.0 } | Should -Throw '*-AllowAnonymous*'
        }
        finally {
            if ($savedKey) { $env:MCPPOSH_API_KEY = $savedKey }
        }
    }

    It 'stops the servers of a knowledge base and then all servers' {
        $srvPort = Get-McpTestFreePort
        Start-McpServer -KnowledgeBase Srv -Port $srvPort -ApiKey $script:WebKey | Out-Null
        @(Get-McpServer).Count | Should -Be 2

        Stop-McpServer -KnowledgeBase Web -Confirm:$false
        Get-McpServer -KnowledgeBase Web | Should -BeNullOrEmpty
        (Get-McpServer -KnowledgeBase Srv).Port | Should -Be $srvPort

        Stop-McpServer -All -Confirm:$false
        Get-McpServer | Should -BeNullOrEmpty
        (Get-McpServer -Uri "http://localhost:$srvPort").Status | Should -Be 'Unreachable'
    }
}
