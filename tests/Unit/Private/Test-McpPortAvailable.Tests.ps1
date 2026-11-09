BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Test-McpPortAvailable' {
    It 'detects used and free ports' {
        InModuleScope MCPPosh {
            $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
            $listener.Start()
            try {
                $port = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
                Test-McpPortAvailable -Port $port | Should -BeFalse
            }
            finally {
                $listener.Stop()
            }
            Test-McpPortAvailable -Port $port | Should -BeTrue
        }
    }
}
