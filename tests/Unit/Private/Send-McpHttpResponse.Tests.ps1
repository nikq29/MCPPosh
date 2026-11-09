BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Send-McpHttpResponse' {
    It 'writes status, headers and body' {
        InModuleScope MCPPosh {
            $port = Get-McpFreePort
            $listener = [System.Net.HttpListener]::new()
            $listener.Prefixes.Add("http://localhost:$port/")
            $listener.Start()
            try {
                $client = [System.Net.Http.HttpClient]::new()
                $pending = $client.GetAsync("http://localhost:$port/")
                $httpContext = $listener.GetContext()
                Send-McpHttpResponse -Response $httpContext.Response -StatusCode 418 -Body '{"a":1}' -Headers @{ 'X-Test' = 'yes' }
                $httpContext.Response.Close()
                $response = $pending.GetAwaiter().GetResult()
                [int]$response.StatusCode | Should -Be 418
                $response.Headers.GetValues('X-Test') | Should -Be 'yes'
                $response.Headers.CacheControl.NoStore | Should -BeTrue
                $response.Content.ReadAsStringAsync().GetAwaiter().GetResult() | Should -Be '{"a":1}'
            }
            finally {
                $listener.Stop()
                $listener.Close()
            }
        }
    }
}
