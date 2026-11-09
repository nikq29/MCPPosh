BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Resolve-McpEndpointUri' {
    It 'appends /mcp to base URLs and keeps endpoints' {
        InModuleScope MCPPosh {
            (Resolve-McpEndpointUri -Uri 'https://docs.example.com').AbsoluteUri | Should -Be 'https://docs.example.com/mcp'
            (Resolve-McpEndpointUri -Uri 'https://docs.example.com/mcp/').AbsoluteUri | Should -Be 'https://docs.example.com/mcp'
            (Resolve-McpEndpointUri -Uri 'http://localhost:5050/mcp').AbsoluteUri | Should -Be 'http://localhost:5050/mcp'
        }
    }

    It 'rejects relative URLs' {
        InModuleScope MCPPosh { { Resolve-McpEndpointUri -Uri ([uri]::new('docs/mcp', [System.UriKind]::Relative)) } | Should -Throw '*not an absolute URL*' }
    }
}
