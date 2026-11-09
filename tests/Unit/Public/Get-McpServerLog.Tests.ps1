BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    New-McpKnowledgeBase -Name Srv | Out-Null
    $logs = Join-Path $env:MCPPOSH_HOME 'knowledgebases/Srv/logs'
    Set-Content -Path (Join-Path $logs 'server-stdio.log') -Value 'stdio line 1', 'stdio line 2'
    Set-Content -Path (Join-Path $logs 'server-5050.log') -Value 'http line 1', 'http line 2', 'http line 3'
    Set-Content -Path (Join-Path $logs 'server-5050.stderr.log') -Value 'stderr'
    (Get-Item (Join-Path $logs 'server-5050.log')).LastWriteTimeUtc = [datetime]::UtcNow.AddMinutes(1)
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpServerLog' {
    It 'shows the stdio log' {
        Get-McpServerLog -KnowledgeBase Srv -Stdio | Should -Be @('stdio line 1', 'stdio line 2')
    }

    It 'shows the log of a port with -Tail' {
        Get-McpServerLog -KnowledgeBase Srv -Port 5050 -Tail 1 | Should -Be 'http line 3'
    }

    It 'shows the most recent log by default and ignores stdout/stderr logs' {
        (Get-McpServerLog -KnowledgeBase Srv)[0] | Should -Be 'http line 1'
    }

    It 'writes an error when no log exists' {
        New-McpKnowledgeBase -Name Empty | Out-Null
        Get-McpServerLog -KnowledgeBase Empty -ErrorAction SilentlyContinue -ErrorVariable err
        $err | Should -Not -BeNullOrEmpty
    }
}
