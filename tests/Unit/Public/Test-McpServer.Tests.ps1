BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    New-McpKnowledgeBase -Name Srv -Description 'Test server' | Out-Null
    Add-McpDocument -KnowledgeBase Srv -Title 'Printer' -Content "# Printer`n`nThe hallway printer is PRN-01 and uses IPP." | Out-Null
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Test-McpServer' {
    It 'runs a full MCP session against the stdio server' {
        $result = Test-McpServer -KnowledgeBase Srv -Query 'printer IPP'
        $result.Error | Should -BeNullOrEmpty
        $result.Success | Should -BeTrue
        $result.Tools | Should -Contain 'search_documentation'
        $result.Documents | Should -Be 1
        $result.TopResult | Should -Be 'Printer'
        $result.Instructions | Should -Match 'Test server'
    }

    It 'tests HTTP servers through the MCP endpoint' {
        InModuleScope MCPPosh {
            Mock Invoke-McpHttpRpc {
                switch ($Message.method) {
                    'initialize' { [ordered]@{ id = $Message.id; result = [ordered]@{ protocolVersion = '2025-11-25'; serverInfo = [ordered]@{ name = 'MCPPosh'; version = '9.9.9' }; instructions = 'x' } } }
                    'tools/list' { [ordered]@{ id = $Message.id; result = [ordered]@{ tools = @([ordered]@{ name = 'search_documentation' }, [ordered]@{ name = 'list_documents' }) } } }
                    'tools/call' {
                        if ($Message.params.name -eq 'list_documents') { [ordered]@{ id = $Message.id; result = [ordered]@{ structuredContent = [ordered]@{ total = 4 } } } }
                        else { [ordered]@{ id = $Message.id; result = [ordered]@{ structuredContent = [ordered]@{ results = @([ordered]@{ title = 'Doc'; heading = 'Doc > Part' }) } } } }
                    }
                    default { $null }
                }
            }
            $result = Test-McpServer -Uri 'http://localhost:5050' -ApiKey 'key' -Query 'anything'
            $result.Target | Should -Be 'http://localhost:5050/mcp'
            $result.ServerVersion | Should -Be '9.9.9'
            $result.Documents | Should -Be 4
            $result.TopResult | Should -Be 'Doc > Part'
            Should -Invoke Invoke-McpHttpRpc -ParameterFilter { $Headers.Authorization -eq 'Bearer key' }
        }
    }

    It 'reports failures instead of throwing' {
        InModuleScope MCPPosh {
            Mock Invoke-McpHttpRpc { throw 'Unauthorized (HTTP 401): missing or invalid API key.' }
            $result = Test-McpServer -Uri 'http://localhost:5050/mcp'
            $result.Success | Should -BeFalse
            $result.Error | Should -Match '401'
        }
    }
}
