BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    New-McpKnowledgeBase -Name Srv | Out-Null
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Restart-McpServer' {
    It 'stops the server and starts it again with the stored settings' {
        InModuleScope MCPPosh {
            $kb = Resolve-McpKnowledgeBase -KnowledgeBase Srv
            Mock Get-McpServerState {
                [pscustomobject]@{ knowledgeBase = 'Srv'; kbPath = $kb.Path; port = 7101; listenAddress = '*'; allowWrite = $true
                    allowAnonymous = $false; allowedOrigins = @('https://app.example.com'); authRequired = $true; Status = 'Running'; StateFile = 'x' }
            }
            Mock Stop-McpServer { }
            Mock Start-McpServer { [pscustomobject]@{ Status = 'Running' } }
            (Restart-McpServer -Port 7101 -ApiKey 'secret').Status | Should -Be 'Running'
            Should -Invoke Stop-McpServer -Times 1 -ParameterFilter { $Port -eq 7101 }
            Should -Invoke Start-McpServer -Times 1 -ParameterFilter {
                $Port -eq 7101 -and $ListenAddress -eq '*' -and $AllowWrite -and ($ApiKey -join ',') -eq 'secret' -and $AllowedOrigin -contains 'https://app.example.com'
            }
        }
    }

    It 'requires the API key again for servers with authentication' {
        InModuleScope MCPPosh {
            Mock Get-McpServerState { [pscustomobject]@{ knowledgeBase = 'Srv'; kbPath = 'x'; port = 7102; authRequired = $true; Status = 'Running' } }
            Mock Start-McpServer { }
            $previous = $env:MCPPOSH_API_KEY
            $env:MCPPOSH_API_KEY = $null
            try {
                Restart-McpServer -Port 7102 -ErrorAction SilentlyContinue -ErrorVariable err
            }
            finally {
                $env:MCPPOSH_API_KEY = $previous
            }
            $err | Should -Not -BeNullOrEmpty
            Should -Invoke Start-McpServer -Times 0
        }
    }

    It 'writes an error when no server matches' {
        Restart-McpServer -Port 7199 -ErrorAction SilentlyContinue -ErrorVariable err
        $err | Should -Not -BeNullOrEmpty
    }
}
