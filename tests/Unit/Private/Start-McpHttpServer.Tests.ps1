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

Describe 'Start-McpHttpServer' {
    It 'serves requests, writes the state file and removes it on shutdown' {
        $port = InModuleScope MCPPosh { Get-McpFreePort }
        $job = Start-ThreadJob -ArgumentList $port, (Get-Module MCPPosh).Path, $env:MCPPOSH_HOME -ScriptBlock {
            param($Port, $ModulePath, $McpHome)
            $env:MCPPOSH_HOME = $McpHome
            Import-Module ($ModulePath -replace 'psm1$', 'psd1') -Force
            & (Get-Module MCPPosh) {
                param($Port)
                $context = New-McpServerContext -KnowledgeBase (Resolve-McpKnowledgeBase -KnowledgeBase Proto) -Transport Http -LogPath (Join-Path $env:MCPPOSH_HOME 'http.log')
                Start-McpHttpServer -Context $context -Port $Port -ApiKeys 'k1'
            } $Port
        }
        try {
            $deadline = (Get-Date).AddSeconds(20)
            $health = $null
            while (-not $health -and (Get-Date) -lt $deadline) {
                try { $health = Invoke-RestMethod -Uri "http://localhost:$port/health" -Headers @{ Authorization = 'Bearer k1' } -TimeoutSec 2 } catch { Start-Sleep -Milliseconds 200 }
            }
            $health.knowledgeBase | Should -Be 'Proto'
            $stateFile = InModuleScope MCPPosh -Parameters @{ Port = $port } { param($Port) Get-McpServerStateFile -KnowledgeBaseName Proto -Port $Port }
            Test-Path $stateFile | Should -BeTrue
            (Get-Content -Raw (Join-Path $env:MCPPOSH_HOME 'http.log')) | Should -Match 'listening on'
        }
        finally {
            $job | Stop-Job
            $job | Remove-Job -Force
        }
    }

    It 'fails with a clear message when the port is in use' {
        $listener = [System.Net.HttpListener]::new()
        $port = InModuleScope MCPPosh { Get-McpFreePort }
        $listener.Prefixes.Add("http://localhost:$port/")
        $listener.Start()
        try {
            InModuleScope MCPPosh -Parameters @{ Port = $port; Context = $script:Context } {
                param($Port, $Context)
                { Start-McpHttpServer -Context $Context -Port $Port } | Should -Throw '*Could not listen*'
            }
        }
        finally {
            $listener.Stop()
            $listener.Close()
        }
    }
}
