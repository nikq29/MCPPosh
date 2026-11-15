BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/PSMcpKnowledgeBase.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'PSMcpKnowledgeBase'
    New-McpKnowledgeBase -Name Srv | Out-Null
    $script:Pwsh = & (Get-Module PSMcpKnowledgeBase) { Get-McpPwshPath }
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpClientConfig' {
    It 'creates a stdio configuration for Claude Desktop' {
        $config = Get-McpClientConfig -KnowledgeBase Srv -Client ClaudeDesktop
        $entry = ($config.Json | ConvertFrom-Json).mcpServers.'psmcpkb-srv'
        $entry.command | Should -Be $script:Pwsh
        $entry.args | Should -Contain '-NoProfile'
        $entry.args[-1] | Should -Match "Start-McpServer -KnowledgeBase 'Srv' -Transport Stdio"
        $entry.env.PSMCPKB_HOME | Should -Be $env:PSMCPKB_HOME
        $config.ConfigFile | Should -Match 'claude_desktop_config.json'
    }

    It 'creates a claude mcp add command for Claude Code' {
        $config = Get-McpClientConfig -KnowledgeBase Srv -Client ClaudeCode -AllowWrite
        $config.Command | Should -Match '^claude mcp add .*psmcpkb-srv -- '
        $config.Command | Should -Match '-AllowWrite'
        ($config.Json | ConvertFrom-Json).mcpServers.'psmcpkb-srv'.type | Should -Be 'stdio'
    }

    It 'quotes the server name in the claude mcp add command' {
        $name = 'my docs; rm -rf x'
        $quoted = InModuleScope PSMcpKnowledgeBase -Parameters @{ Name = $name } { param($Name) ConvertTo-McpShellArgument -Value $Name }
        # The test environment sets PSMCPKB_HOME, which adds '-e PSMCPKB_HOME=...' before the name.
        (Get-McpClientConfig -KnowledgeBase Srv -Client ClaudeCode -ServerName $name).Command | Should -BeLike "claude mcp add* $quoted -- *"
        (Get-McpClientConfig -KnowledgeBase Srv -Client ClaudeCode -Transport Http -Uri 'https://docs.example.com/mcp' -ServerName $name).Command |
            Should -BeLike "claude mcp add --transport http $quoted https://docs.example.com/mcp"
    }

    It 'imports the module by name when requested or when it is installed in a module folder' {
        (Get-McpClientConfig -KnowledgeBase Srv -UseModuleName -AsJson | ConvertFrom-Json).mcpServers.'psmcpkb-srv'.args[-1] | Should -Match '^Import-Module PSMcpKnowledgeBase;'
        InModuleScope PSMcpKnowledgeBase {
            $original = $script:ModuleManifestPath
            $root = if ($IsWindows) { Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell/Modules' } else { Join-Path $HOME '.local/share/powershell/Modules' }
            $script:ModuleManifestPath = Join-Path $root 'PSMcpKnowledgeBase/1.0.0/PSMcpKnowledgeBase.psd1'
            try {
                (Get-McpClientConfig -KnowledgeBase Srv -AsJson | ConvertFrom-Json).mcpServers.'psmcpkb-srv'.args[-1] | Should -Match '^Import-Module PSMcpKnowledgeBase;'
            }
            finally {
                $script:ModuleManifestPath = $original
            }
        }
    }

    It 'creates an HTTP configuration for VS Code with a key prompt' {
        $json = Get-McpClientConfig -KnowledgeBase Srv -Client VSCode -Transport Http -Uri 'https://docs.example.com' -ApiKeyPlaceholder -AsJson | ConvertFrom-Json
        $json.servers.'psmcpkb-srv'.type | Should -Be 'http'
        $json.servers.'psmcpkb-srv'.url | Should -Be 'https://docs.example.com/mcp'
        $json.servers.'psmcpkb-srv'.headers.Authorization | Should -Be 'Bearer ${input:psmcpkb-api-key}'
        $json.inputs[0].password | Should -BeTrue
    }

    It 'creates HTTP configurations for Cursor, Claude Code, Claude Desktop and generic clients' {
        $cursor = Get-McpClientConfig -KnowledgeBase Srv -Client Cursor -Transport Http -Uri 'https://docs.example.com/mcp' -ApiKey 'abc' -AsJson | ConvertFrom-Json
        $cursor.mcpServers.'psmcpkb-srv'.headers.Authorization | Should -Be 'Bearer abc'
        $code = Get-McpClientConfig -KnowledgeBase Srv -Client ClaudeCode -Transport Http -Uri 'https://docs.example.com/mcp' -ApiKey 'abc'
        $code.Command | Should -Match '^claude mcp add --transport http psmcpkb-srv https://docs.example.com/mcp --header'
        $code.Notes | Should -Match 'plain text'
        $desktop = Get-McpClientConfig -KnowledgeBase Srv -Client ClaudeDesktop -Transport Http -Uri 'https://docs.example.com/mcp' -ApiKey 'abc' -AsJson | ConvertFrom-Json
        $desktop.mcpServers.'psmcpkb-srv'.args | Should -Contain 'mcp-remote'
        $generic = Get-McpClientConfig -KnowledgeBase Srv -Transport Http -Uri 'https://docs.example.com/mcp' -AsJson | ConvertFrom-Json
        $generic.mcpServers.'psmcpkb-srv'.url | Should -Be 'https://docs.example.com/mcp'
    }

    It 'uses the running local HTTP server when no -Uri is given' {
        InModuleScope PSMcpKnowledgeBase {
            $kb = Resolve-McpKnowledgeBase -KnowledgeBase Srv
            Mock Get-McpServerState { [pscustomobject]@{ kbPath = $kb.Path; Status = 'Running'; url = 'http://localhost:5055/mcp' } }
            (Get-McpClientConfig -KnowledgeBase Srv -Transport Http -AsJson | ConvertFrom-Json).mcpServers.'psmcpkb-srv'.url | Should -Be 'http://localhost:5055/mcp'
        }
    }

    It 'requires a running server or -Uri for HTTP' {
        { Get-McpClientConfig -KnowledgeBase Srv -Transport Http } | Should -Throw '*No running HTTP server*'
    }
}
