BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpServerState' {
    It 'marks running and stale servers' {
        InModuleScope MCPPosh {
            $self = [System.Diagnostics.Process]::GetCurrentProcess()
            Write-McpJsonFile -Path (Get-McpServerStateFile -KnowledgeBaseName A -Port 1) -InputObject ([ordered]@{ pid = $PID; processStartTime = $self.StartTime.ToUniversalTime().ToString('o'); port = 1 })
            Write-McpJsonFile -Path (Get-McpServerStateFile -KnowledgeBaseName B -Port 2) -InputObject ([ordered]@{ pid = 999999; port = 2 })
            Set-Content -Path (Join-Path (Get-McpServerStateRoot) 'broken.json') -Value '{broken'
            $states = @(Get-McpServerState)
            ($states | Where-Object port -EQ 1).Status | Should -Be 'Running'
            ($states | Where-Object port -EQ 2).Status | Should -Be 'Stale'
            $states.Count | Should -Be 2
        }
    }
}
