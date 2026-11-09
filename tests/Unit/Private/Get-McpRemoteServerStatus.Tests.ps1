BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpRemoteServerStatus' {
    It 'reports Unauthorized when a key is rejected' {
        InModuleScope MCPPosh {
            Mock Invoke-WebRequest { [pscustomobject]@{ StatusCode = 200; Content = '{"status":"ok","server":"MCPPosh","version":"1.0.0"}' } }
            (Get-McpRemoteServerStatus -Uri 'https://docs.example.com' -ApiKey 'wrong').Status | Should -Be 'Unauthorized'
            (Get-McpRemoteServerStatus -Uri 'https://docs.example.com').Status | Should -Be 'Running'
        }
    }

    It 'reports HTTP errors' {
        InModuleScope MCPPosh {
            Mock Invoke-WebRequest { [pscustomobject]@{ StatusCode = 503; Content = '' } }
            (Get-McpRemoteServerStatus -Uri 'https://docs.example.com/mcp').Status | Should -Be 'HTTP 503'
        }
    }
}
