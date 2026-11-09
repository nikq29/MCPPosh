BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    $script:Files = Join-Path $script:TestHome 'files'
    New-Item -ItemType Directory -Path $script:Files -Force | Out-Null
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Resolve-McpUrl' {
    It 'resolves relative links against the base URL' {
        InModuleScope MCPPosh {
            Resolve-McpUrl -Href 'details.html' -BaseUrl 'https://docs.example.com/vpn/index.html' | Should -Be 'https://docs.example.com/vpn/details.html'
            Resolve-McpUrl -Href '/root' -BaseUrl 'https://docs.example.com/a/b' | Should -Be 'https://docs.example.com/root'
        }
    }

    It 'returns the link unchanged without base URL' {
        InModuleScope MCPPosh { Resolve-McpUrl -Href 'details.html' | Should -Be 'details.html' }
    }
}
