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

Describe 'Start-McpStdioServer' {
    It 'answers JSON-RPC lines on stdout and logs to the knowledge base' {
        $manifest = (Get-Module MCPPosh).Path -replace 'psm1$', 'psd1'
        $pwsh = InModuleScope MCPPosh { Get-McpPwshPath }
        $command = "Import-Module '$manifest'; & (Get-Module MCPPosh) { Start-McpStdioServer -Context (New-McpServerContext -KnowledgeBase (Resolve-McpKnowledgeBase -KnowledgeBase Proto)) }"
        $output = @('{"jsonrpc":"2.0","id":1,"method":"ping"}', '', 'not json') | & $pwsh -NoProfile -NonInteractive -Command $command 2>$null
        $lines = @($output | Where-Object { $_ })
        $lines.Count | Should -Be 2
        ($lines[0] | ConvertFrom-Json).id | Should -Be 1
        ($lines[1] | ConvertFrom-Json).error.code | Should -Be -32700
        Get-Content -Raw (Join-Path $env:MCPPOSH_HOME 'knowledgebases/Proto/logs/server-stdio.log') | Should -Match 'stdio server stopped'
    }
}
