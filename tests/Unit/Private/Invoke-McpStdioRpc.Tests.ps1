BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    New-McpKnowledgeBase -Name Proto -Description 'Protocol tests' | Out-Null
    Add-McpDocument -KnowledgeBase Proto -Title 'Backup' -Content "# Backup`n`nThe nightly backup runs at 02:00 with Veeam." -Tags ops | Out-Null
    Add-McpDocument -KnowledgeBase Proto -Title 'Onboarding' -Content ("# Onboarding`n`n" + ('New employees receive their laptop on the first day. ' * 40)) -Tags hr | Out-Null
    $script:Context = New-McpTestContext -KnowledgeBase Proto
    $script:WriteContext = New-McpTestContext -KnowledgeBase Proto -AllowWrite
    $script:KbPath = & (Get-Module MCPPosh) { (Resolve-McpKnowledgeBase -KnowledgeBase Proto).Path }
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Invoke-McpStdioRpc' {
    It 'exchanges messages with a stdio server process' {
        InModuleScope MCPPosh -Parameters @{ KbPath = $script:KbPath } {
            param($KbPath)
            $client = Start-McpStdioClient -KbPath $KbPath
            try {
                $init = Invoke-McpStdioRpc -Client $client -Message ([ordered]@{ jsonrpc = '2.0'; id = 1; method = 'initialize'; params = [ordered]@{ protocolVersion = '2025-06-18' } })
                $init.result.serverInfo.name | Should -Be 'MCPPosh'
                Invoke-McpStdioRpc -Client $client -Message ([ordered]@{ jsonrpc = '2.0'; method = 'notifications/initialized' }) | Should -BeNullOrEmpty
                (Invoke-McpStdioRpc -Client $client -Message ([ordered]@{ jsonrpc = '2.0'; id = 2; method = 'ping' })).id | Should -Be 2
            }
            finally {
                Stop-McpStdioClient -Client $client
            }
        }
    }
}
