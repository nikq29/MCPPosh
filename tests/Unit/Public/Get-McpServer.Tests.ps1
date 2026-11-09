BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    New-McpKnowledgeBase -Name Srv | Out-Null
    & (Get-Module MCPPosh) {
        $kb = Resolve-McpKnowledgeBase -KnowledgeBase Srv
        $self = [System.Diagnostics.Process]::GetCurrentProcess()
        Write-McpJsonFile -Path (Get-McpServerStateFile -KnowledgeBaseName Srv -Port 7001) -InputObject ([ordered]@{
                pid = $PID; processStartTime = $self.StartTime.ToUniversalTime().ToString('o'); knowledgeBase = 'Srv'; kbPath = $kb.Path
                transport = 'Http'; port = 7001; listenAddress = 'localhost'; url = 'http://localhost:7001/mcp'; allowWrite = $true
                authRequired = $true; allowedOrigins = @('https://app.example.com'); startedAt = Get-McpUtcNow; version = '1.0.0'
            })
        Write-McpJsonFile -Path (Get-McpServerStateFile -KnowledgeBaseName Srv -Port 7002) -InputObject ([ordered]@{
                pid = 999999; processStartTime = '2000-01-01T00:00:00.0000000Z'; knowledgeBase = 'Srv'; kbPath = $kb.Path
                transport = 'Http'; port = 7002; url = 'http://localhost:7002/mcp'; startedAt = Get-McpUtcNow
            })
    }
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    & (Get-Module MCPPosh) { Get-ChildItem (Get-McpServerStateRoot) -Filter *.json | Remove-Item -Force }
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpServer' {
    It 'lists running local servers with their settings' {
        $server = Get-McpServer -Port 7001
        $server.Status | Should -Be 'Running'
        $server.KnowledgeBase | Should -Be 'Srv'
        $server.Url | Should -Be 'http://localhost:7001/mcp'
        $server.AuthRequired | Should -BeTrue
        $server.AllowWrite | Should -BeTrue
        $server.AllowedOrigins | Should -Be @('https://app.example.com')
        $server.Uptime | Should -BeOfType [timespan]
    }

    It 'reports stale servers once as Stopped and forgets them' {
        (Get-McpServer -Port 7002).Status | Should -Be 'Stopped'
        Get-McpServer -Port 7002 | Should -BeNullOrEmpty
    }

    It 'filters by knowledge base' {
        Get-McpServer -KnowledgeBase Other | Should -BeNullOrEmpty
        (Get-McpServer -KnowledgeBase 'Sr*').Port | Should -Be 7001
    }

    It 'queries the health endpoint of a remote server' {
        InModuleScope MCPPosh {
            Mock Invoke-WebRequest {
                [pscustomobject]@{ StatusCode = 200; Content = '{"status":"ok","server":"MCPPosh","version":"1.2.3","knowledgeBase":"Contoso","documents":12,"revision":7,"uptimeSeconds":90,"authRequired":true,"allowWrite":false}' }
            } -ParameterFilter { $Uri -eq 'https://docs.example.com/health' -and $Headers.Authorization -eq 'Bearer key' }
            $remote = Get-McpServer -Uri 'https://docs.example.com/mcp' -ApiKey 'key'
            $remote.Status | Should -Be 'Running'
            $remote.KnowledgeBase | Should -Be 'Contoso'
            $remote.Documents | Should -Be 12
            $remote.Version | Should -Be '1.2.3'
        }
    }

    It 'reports unreachable remote servers' {
        InModuleScope MCPPosh {
            Mock Invoke-WebRequest { throw 'connection refused' }
            $remote = Get-McpServer -Uri 'https://down.example.com'
            $remote.Status | Should -Be 'Unreachable'
            $remote.Error | Should -Match 'connection refused'
        }
    }
}
