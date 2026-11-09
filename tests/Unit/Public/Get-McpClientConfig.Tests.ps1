BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    New-McpKnowledgeBase -Name Srv | Out-Null
    $script:Pwsh = & (Get-Module MCPPosh) { Get-McpPwshPath }
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpClientConfig' {
    It 'creates a stdio configuration for Claude Desktop' {
        $config = Get-McpClientConfig -KnowledgeBase Srv -Client ClaudeDesktop
        $entry = ($config.Json | ConvertFrom-Json).mcpServers.'mcpposh-srv'
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

    It 'imports the module by name when requested or when it is installed in a module folder' {
        (Get-McpClientConfig -KnowledgeBase Srv -UseModuleName -AsJson | ConvertFrom-Json).mcpServers.'mcpposh-srv'.args[-1] | Should -Match '^Import-Module MCPPosh;'
        InModuleScope MCPPosh {
            $original = $script:ModuleManifestPath
            $root = if ($IsWindows) { Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell/Modules' } else { Join-Path $HOME '.local/share/powershell/Modules' }
            $script:ModuleManifestPath = Join-Path $root 'MCPPosh/1.0.0/MCPPosh.psd1'
            try {
                (Get-McpClientConfig -KnowledgeBase Srv -AsJson | ConvertFrom-Json).mcpServers.'mcpposh-srv'.args[-1] | Should -Match '^Import-Module MCPPosh;'
            }
            finally {
                $script:ModuleManifestPath = $original
            }
        }
    }

    It 'creates an HTTP configuration for VS Code with a key prompt' {
        $json = Get-McpClientConfig -KnowledgeBase Srv -Client VSCode -Transport Http -Uri 'https://docs.example.com' -ApiKeyPlaceholder -AsJson | ConvertFrom-Json
        $json.servers.'mcpposh-srv'.type | Should -Be 'http'
        $json.servers.'mcpposh-srv'.url | Should -Be 'https://docs.example.com/mcp'
        $json.servers.'mcpposh-srv'.headers.Authorization | Should -Be 'Bearer ${input:mcpposh-api-key}'
        $json.inputs[0].password | Should -BeTrue
    }

    It 'creates HTTP configurations for Cursor, Claude Code, Claude Desktop and generic clients' {
        $cursor = Get-McpClientConfig -KnowledgeBase Srv -Client Cursor -Transport Http -Uri 'https://docs.example.com/mcp' -ApiKey 'abc' -AsJson | ConvertFrom-Json
        $cursor.mcpServers.'mcpposh-srv'.headers.Authorization | Should -Be 'Bearer abc'
        $code = Get-McpClientConfig -KnowledgeBase Srv -Client ClaudeCode -Transport Http -Uri 'https://docs.example.com/mcp' -ApiKey 'abc'
        $code.Command | Should -Match '^claude mcp add --transport http mcpposh-srv https://docs.example.com/mcp --header'
        $code.Notes | Should -Match 'plain text'
        $desktop = Get-McpClientConfig -KnowledgeBase Srv -Client ClaudeDesktop -Transport Http -Uri 'https://docs.example.com/mcp' -ApiKey 'abc' -AsJson | ConvertFrom-Json
        $desktop.mcpServers.'mcpposh-srv'.args | Should -Contain 'mcp-remote'
        $generic = Get-McpClientConfig -KnowledgeBase Srv -Transport Http -Uri 'https://docs.example.com/mcp' -AsJson | ConvertFrom-Json
        $generic.mcpServers.'mcpposh-srv'.url | Should -Be 'https://docs.example.com/mcp'
    }

    It 'uses the running local HTTP server when no -Uri is given' {
        InModuleScope MCPPosh {
            $kb = Resolve-McpKnowledgeBase -KnowledgeBase Srv
            Mock Get-McpServerState { [pscustomobject]@{ kbPath = $kb.Path; Status = 'Running'; url = 'http://localhost:5055/mcp' } }
            (Get-McpClientConfig -KnowledgeBase Srv -Transport Http -AsJson | ConvertFrom-Json).mcpServers.'mcpposh-srv'.url | Should -Be 'http://localhost:5055/mcp'
        }
    }

    It 'requires a running server or -Uri for HTTP' {
        { Get-McpClientConfig -KnowledgeBase Srv -Transport Http } | Should -Throw '*No running HTTP server*'
    }
}
