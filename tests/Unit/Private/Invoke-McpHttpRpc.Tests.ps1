BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Invoke-McpHttpRpc' {
    It 'sends a request and parses JSON responses' {
        InModuleScope MCPPosh {
            Mock Invoke-WebRequest { [pscustomobject]@{ StatusCode = 200; Content = '{"jsonrpc":"2.0","id":1,"result":{}}'; Headers = @{ 'Content-Type' = 'application/json' } } } -ParameterFilter { $Headers.Accept -like '*text/event-stream*' -and $Headers.Authorization -eq 'Bearer k' }
            (Invoke-McpHttpRpc -Endpoint 'http://localhost:1/mcp' -Message ([ordered]@{ jsonrpc = '2.0'; id = 1; method = 'ping' }) -Headers @{ Authorization = 'Bearer k' }).id | Should -Be 1
        }
    }

    It 'parses server-sent event responses' {
        InModuleScope MCPPosh {
            Mock Invoke-WebRequest { [pscustomobject]@{ StatusCode = 200; Content = "event: message`ndata: {`"jsonrpc`":`"2.0`",`"id`":5,`"result`":{`"ok`":true}}`n`n"; Headers = @{ 'Content-Type' = 'text/event-stream' } } }
            (Invoke-McpHttpRpc -Endpoint 'http://localhost:1/mcp' -Message ([ordered]@{ jsonrpc = '2.0'; id = 5; method = 'ping' })).result.ok | Should -BeTrue
        }
    }

    It 'returns $null for notifications and throws on HTTP errors' {
        InModuleScope MCPPosh {
            Mock Invoke-WebRequest { [pscustomobject]@{ StatusCode = 202; Content = ''; Headers = @{} } }
            Invoke-McpHttpRpc -Endpoint 'http://localhost:1/mcp' -Message ([ordered]@{ jsonrpc = '2.0'; method = 'notifications/initialized' }) | Should -BeNullOrEmpty
            Mock Invoke-WebRequest { [pscustomobject]@{ StatusCode = 401; Content = ''; Headers = @{} } }
            { Invoke-McpHttpRpc -Endpoint 'http://localhost:1/mcp' -Message ([ordered]@{ jsonrpc = '2.0'; id = 1; method = 'ping' }) } | Should -Throw '*401*'
            Mock Invoke-WebRequest { [pscustomobject]@{ StatusCode = 500; Content = 'oops'; Headers = @{} } }
            { Invoke-McpHttpRpc -Endpoint 'http://localhost:1/mcp' -Message ([ordered]@{ jsonrpc = '2.0'; id = 1; method = 'ping' }) } | Should -Throw '*HTTP 500*'
        }
    }
}
