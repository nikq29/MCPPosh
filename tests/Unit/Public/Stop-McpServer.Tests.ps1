BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    New-McpKnowledgeBase -Name Srv | Out-Null
    function New-TestServerState {
        param([int] $Port, [System.Diagnostics.Process] $Process, [string] $KnowledgeBase = 'Srv')
        & (Get-Module MCPPosh) {
            param($Port, $Process, $KnowledgeBase)
            $kb = Resolve-McpKnowledgeBase -KnowledgeBase $KnowledgeBase
            Write-McpJsonFile -Path (Get-McpServerStateFile -KnowledgeBaseName $KnowledgeBase -Port $Port) -InputObject ([ordered]@{
                    pid = $Process.Id; processStartTime = $Process.StartTime.ToUniversalTime().ToString('o')
                    knowledgeBase = $KnowledgeBase; kbPath = $kb.Path; transport = 'Http'; port = $Port
                    url = "http://localhost:$Port/mcp"; startedAt = Get-McpUtcNow
                })
        } $Port $Process $KnowledgeBase
    }
    function Start-TestSleeper {
        $pwsh = & (Get-Module MCPPosh) { Get-McpPwshPath }
        Start-Process -FilePath $pwsh -ArgumentList '-NoProfile', '-Command', 'Start-Sleep -Seconds 120' -PassThru
    }
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Stop-McpServer' {
    It 'stops the server process on a port and removes its state file' {
        $process = Start-TestSleeper
        New-TestServerState -Port 6001 -Process $process
        Stop-McpServer -Port 6001 -Confirm:$false
        $process.WaitForExit(10000) | Should -BeTrue
        Get-McpServer -Port 6001 | Should -BeNullOrEmpty
    }

    It 'requires a filter when several servers are running' {
        $first = Start-TestSleeper
        $second = Start-TestSleeper
        New-TestServerState -Port 6002 -Process $first
        New-TestServerState -Port 6003 -Process $second
        Stop-McpServer -ErrorAction SilentlyContinue -ErrorVariable err
        $err | Should -Not -BeNullOrEmpty
        Get-McpServer | Stop-McpServer -Confirm:$false
        $first.WaitForExit(10000) | Should -BeTrue
        $second.WaitForExit(10000) | Should -BeTrue
    }

    It 'stops all servers with -All and cleans up stale state files' {
        $process = Start-TestSleeper
        New-TestServerState -Port 6004 -Process $process
        $stale = Start-TestSleeper
        New-TestServerState -Port 6005 -Process $stale
        $stale.Kill(); $stale.WaitForExit()
        Stop-McpServer -All -Confirm:$false
        $process.WaitForExit(10000) | Should -BeTrue
        @(InModuleScope MCPPosh { Get-McpServerState }).Count | Should -Be 0
    }

    It 'keeps the server with -WhatIf' {
        $process = Start-TestSleeper
        New-TestServerState -Port 6006 -Process $process
        Stop-McpServer -Port 6006 -WhatIf
        $process.HasExited | Should -BeFalse
        Stop-McpServer -Port 6006 -Confirm:$false
        $process.WaitForExit(10000) | Should -BeTrue
    }

    It 'writes an error when no server matches' {
        Stop-McpServer -Port 6099 -ErrorAction SilentlyContinue -ErrorVariable err
        $err | Should -Not -BeNullOrEmpty
    }
}
