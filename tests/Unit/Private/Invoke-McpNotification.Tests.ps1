BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    New-McpKnowledgeBase -Name Proto -Description 'Protocol tests' | Out-Null
    Add-McpDocument -KnowledgeBase Proto -Title 'Backup' -Content "# Backup`n`nThe nightly backup runs at 02:00 with Veeam." -Tags ops | Out-Null
    Add-McpDocument -KnowledgeBase Proto -Title 'Onboarding' -Content ("# Onboarding`n`n" + ('New employees receive their laptop on the first day. ' * 40)) -Tags hr | Out-Null
    $script:Context = New-McpTestContext -KnowledgeBase Proto
    $script:WriteContext = New-McpTestContext -KnowledgeBase Proto -AllowWrite
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Invoke-McpNotification' {
    It 'logs known and unknown notifications' {
        InModuleScope MCPPosh -Parameters @{ Context = $script:Context } {
            param($Context)
            Invoke-McpNotification -Context $Context -Method 'notifications/initialized'
            Invoke-McpNotification -Context $Context -Method 'notifications/cancelled' -Params ([ordered]@{ requestId = 7 })
            Invoke-McpNotification -Context $Context -Method 'notifications/other'
            $log = Get-Content -Raw $Context.LogPath
            $log | Should -Match 'Client initialized'
            $log | Should -Match "cancelled request '7'"
            $log | Should -Match 'Ignored notification: notifications/other'
        }
    }
}
