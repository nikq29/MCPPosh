<#
    End-to-end tests of Get-McpClientConfig: the generated stdio configurations are started as real processes and
    the HTTP configurations are used to call a running server, so every configuration is proven to work. No mocks.
#>
BeforeDiscovery {
    $script:StdioClients = @('ClaudeDesktop', 'ClaudeCode', 'VSCode', 'Cursor', 'Generic' | ForEach-Object { @{ Client = $_ } })
    $script:HttpClients = @('ClaudeCode', 'VSCode', 'Cursor', 'Generic' | ForEach-Object { @{ Client = $_ } })
}

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment -Name client
    New-McpKnowledgeBase -Name Client -Description 'Client configuration tests' | Out-Null
    Add-McpDocument -KnowledgeBase Client -Title 'VPN' -Content "# VPN`n`nThe VPN gateway vpn.contoso.example uses WireGuard." | Out-Null
    $script:SearchCall = @{ Name = 'search_documentation'; Arguments = @{ query = 'vpn gateway' } }
    $script:Initialize = (Get-McpTestRpcMessage)[0]
}

AfterAll {
    Stop-McpServer -All -Confirm:$false -ErrorAction SilentlyContinue
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Stdio configurations' {
    It 'starts a working server with the <Client> configuration' -ForEach $StdioClients {
        $config = Get-McpClientConfig -KnowledgeBase Client -Client $Client
        $config.Client | Should -Be $Client
        $config.Transport | Should -Be 'Stdio'
        $config.ServerName | Should -Be 'mcpposh-client'
        $server = Get-McpTestClientEntry -Json $config.Json
        $server.Name | Should -Be 'mcpposh-client'
        if ($Client -in 'VSCode', 'ClaudeCode') { $server.Entry.type | Should -Be 'stdio' }
        if ($Client -eq 'VSCode') { $server.Config.Keys | Should -Contain 'servers' } else { $server.Config.Keys | Should -Contain 'mcpServers' }
        if ($Client -eq 'ClaudeCode') { $config.Command | Should -Match '^claude mcp add .*mcpposh-client -- ' }

        $session = Invoke-McpTestStdioSession -FilePath $server.Entry.command -ArgumentList $server.Entry.args -Environment $server.Entry.env `
            -Message (Get-McpTestRpcMessage -ListTools -ToolCall $script:SearchCall)
        $session.Responses.Count | Should -Be 3 -Because $session.StdErr
        $session.Responses[0].result.serverInfo.name | Should -Be 'MCPPosh'
        $session.Responses[1].result.tools.name | Should -Not -Contain 'add_note'
        $session.Responses[2].result.content[0].text | Should -Match 'WireGuard'
    }

    It 'allows agents to add notes with -AllowWrite and uses the -ServerName' {
        $json = Get-McpClientConfig -KnowledgeBase Client -AllowWrite -ServerName docs -AsJson
        $json | Should -BeOfType [string]
        $server = Get-McpTestClientEntry -Json $json
        $server.Name | Should -Be 'docs'
        $note = @{ Name = 'add_note'; Arguments = @{ title = 'Agent note'; content = 'The agent learned that the VPN MTU is 1380.' } }
        $session = Invoke-McpTestStdioSession -FilePath $server.Entry.command -ArgumentList $server.Entry.args -Environment $server.Entry.env `
            -Message (Get-McpTestRpcMessage -ListTools -ToolCall $note)
        $session.Responses[1].result.tools.name | Should -Contain 'add_note'
        $session.Responses[2].result.isError | Should -Not -BeTrue
        (Get-McpDocument -KnowledgeBase Client -SourceType Agent).Title | Should -Be 'Agent note'
    }

    It 'imports the module by name with -UseModuleName' {
        $server = Get-McpTestClientEntry -Json (Get-McpClientConfig -KnowledgeBase Client -UseModuleName -AsJson)
        $server.Entry.args[-1] | Should -Match '^Import-Module MCPPosh;'
        # The module must be found on PSModulePath, as after Install-PSResource MCPPosh.
        $moduleRoot = Get-McpTestModuleManifest | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent
        $environment = @{ MCPPOSH_HOME = $server.Entry.env.MCPPOSH_HOME; PSModulePath = $moduleRoot + [System.IO.Path]::PathSeparator + $env:PSModulePath }
        $session = Invoke-McpTestStdioSession -FilePath $server.Entry.command -ArgumentList $server.Entry.args -Environment $environment `
            -Message (Get-McpTestRpcMessage -ToolCall $script:SearchCall)
        $session.Responses[-1].result.content[0].text | Should -Match 'WireGuard' -Because $session.StdErr
    }
}

Describe 'HTTP configurations' {
    BeforeAll {
        $script:Port = Get-McpTestFreePort
        $script:Key = 'client-key-' + [guid]::NewGuid().ToString('N')
        Start-McpServer -KnowledgeBase Client -Port $script:Port -ApiKey $script:Key | Out-Null
        $script:Base = "http://localhost:$($script:Port)"
    }

    AfterAll {
        Stop-McpServer -Port $script:Port -Confirm:$false -ErrorAction SilentlyContinue
    }

    It 'reaches the server with the url and headers of the <Client> configuration' -ForEach $HttpClients {
        $config = Get-McpClientConfig -KnowledgeBase Client -Client $Client -Transport Http -Uri $script:Base -ApiKey $script:Key
        $config.Notes | Should -Match 'plain text'
        $entry = (Get-McpTestClientEntry -Json $config.Json).Entry
        $entry.url | Should -Be "$($script:Base)/mcp"
        $response = Invoke-RestMethod -Uri $entry.url -Method Post -Body $script:Initialize -ContentType 'application/json' -Headers $entry.headers
        $response.result.serverInfo.name | Should -Be 'MCPPosh'
        if ($Client -eq 'ClaudeCode') { $config.Command | Should -Match "^claude mcp add --transport http mcpposh-client $([regex]::Escape($entry.url))" }
    }

    It 'finds the running local server when -Uri is omitted' {
        $entry = (Get-McpTestClientEntry -Json (Get-McpClientConfig -KnowledgeBase Client -Transport Http -AsJson)).Entry
        $entry.url | Should -Be "$($script:Base)/mcp"
        (Invoke-WebRequest -Uri $entry.url -Method Post -Body $script:Initialize -ContentType 'application/json' -SkipHttpErrorCheck).StatusCode | Should -Be 401
    }

    It 'writes placeholders instead of the API key with -ApiKeyPlaceholder' {
        $json = Get-McpClientConfig -KnowledgeBase Client -Client VSCode -Transport Http -Uri $script:Base -ApiKeyPlaceholder -AsJson
        $json | Should -Not -Match $script:Key
        $server = Get-McpTestClientEntry -Json $json
        $server.Config.inputs[0].id | Should -Be 'mcpposh-api-key'
        $server.Config.inputs[0].password | Should -BeTrue
        $server.Entry.headers.Authorization | Should -Be 'Bearer ${input:mcpposh-api-key}'
        # VS Code replaces the input with the key the user enters.
        $headers = @{ Authorization = $server.Entry.headers.Authorization.Replace('${input:mcpposh-api-key}', $script:Key) }
        (Invoke-RestMethod -Uri $server.Entry.url -Method Post -Body $script:Initialize -ContentType 'application/json' -Headers $headers).result.serverInfo.name |
            Should -Be 'MCPPosh'
    }

    It 'configures the mcp-remote bridge for Claude Desktop' {
        $entry = (Get-McpTestClientEntry -Json (Get-McpClientConfig -KnowledgeBase Client -Client ClaudeDesktop -Transport Http -Uri $script:Base -ApiKey $script:Key -AsJson)).Entry
        $entry.command | Should -Be 'npx'
        $entry.args | Should -Be @('-y', 'mcp-remote', "$($script:Base)/mcp", '--header', 'Authorization:${MCPPOSH_AUTH_HEADER}')
        $entry.env.MCPPOSH_AUTH_HEADER | Should -Be "Bearer $($script:Key)"
        # mcp-remote (Node.js) is not started; send the request it would send.
        $headers = @{ Authorization = $entry.env.MCPPOSH_AUTH_HEADER }
        (Invoke-RestMethod -Uri $entry.args[2] -Method Post -Body $script:Initialize -ContentType 'application/json' -Headers $headers).result.serverInfo.name |
            Should -Be 'MCPPosh'
    }
}
