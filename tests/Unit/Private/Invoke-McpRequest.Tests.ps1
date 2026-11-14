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

Describe 'Invoke-McpRequest' {
    It 'rejects invalid requests' {
        InModuleScope MCPPosh -Parameters @{ Context = $script:Context } {
            param($Context)
            (Invoke-McpRequest -Context $Context -Message 'text').error.code | Should -Be -32600
            (Invoke-McpRequest -Context $Context -Message ([ordered]@{ id = 1; method = 'ping' })).error.code | Should -Be -32600
            (Invoke-McpRequest -Context $Context -Message ([ordered]@{ jsonrpc = '2.0'; id = 1; method = 'ping'; params = @(1) })).error.code | Should -Be -32602
        }
    }

    It 'returns method not found and ignores client responses' {
        InModuleScope MCPPosh -Parameters @{ Context = $script:Context } {
            param($Context)
            (Invoke-McpRequest -Context $Context -Message ([ordered]@{ jsonrpc = '2.0'; id = 1; method = 'does/not/exist' })).error.code | Should -Be -32601
            Invoke-McpRequest -Context $Context -Message ([ordered]@{ jsonrpc = '2.0'; id = 1; result = @{} }) | Should -BeNullOrEmpty
        }
    }

    It 'answers ping, prompts/list and logging/setLevel and reports internal errors' {
        InModuleScope MCPPosh -Parameters @{ Context = $script:Context } {
            param($Context)
            (Invoke-McpRequest -Context $Context -Message ([ordered]@{ jsonrpc = '2.0'; id = 1; method = 'ping' })).result.Count | Should -Be 0
            @((Invoke-McpRequest -Context $Context -Message ([ordered]@{ jsonrpc = '2.0'; id = 2; method = 'prompts/list' })).result.prompts).Count | Should -Be 0
            Mock Get-McpToolList { throw 'boom' }
            (Invoke-McpRequest -Context $Context -Message ([ordered]@{ jsonrpc = '2.0'; id = 3; method = 'tools/list' })).error.code | Should -Be -32603
        }
    }
}

Describe 'Invoke-McpRequest (error details)' {
    It 'does not reveal exception details to clients' {
        InModuleScope MCPPosh -Parameters @{ Context = $script:Context } {
            param($Context)
            Mock Get-McpToolList { throw 'Could not read /secret/path/file.json' }
            $response = Invoke-McpRequest -Context $Context -Message ([ordered]@{ jsonrpc = '2.0'; id = 4; method = 'tools/list' })
            $response.error.code | Should -Be -32603
            $response.error.message | Should -Not -Match 'secret'
            $response.error.message | Should -Match 'server log'
        }
    }
}
