BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Test-McpLoopbackAddress' {
    It 'recognizes loopback addresses' -ForEach @('localhost', '127.0.0.1', '::1', '[::1]') {
        InModuleScope MCPPosh -Parameters @{ Address = $_ } { param($Address) Test-McpLoopbackAddress -Address $Address | Should -BeTrue }
    }

    It 'treats other addresses as network addresses' -ForEach @('*', '0.0.0.0', 'docs.example.com') {
        InModuleScope MCPPosh -Parameters @{ Address = $_ } { param($Address) Test-McpLoopbackAddress -Address $Address | Should -BeFalse }
    }
}
