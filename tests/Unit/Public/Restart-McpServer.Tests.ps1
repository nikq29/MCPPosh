BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/PSMcpKnowledgeBase.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'PSMcpKnowledgeBase'
    New-McpKnowledgeBase -Name Srv | Out-Null
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Restart-McpServer' {
    It 'stops the server and starts it again with the stored settings' {
        InModuleScope PSMcpKnowledgeBase {
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
        InModuleScope PSMcpKnowledgeBase {
            Mock Get-McpServerState { [pscustomobject]@{ knowledgeBase = 'Srv'; kbPath = 'x'; port = 7102; authRequired = $true; Status = 'Running' } }
            Mock Start-McpServer { }
            $previous = $env:PSMCPKB_API_KEY
            $env:PSMCPKB_API_KEY = $null
            try {
                Restart-McpServer -Port 7102 -ErrorAction SilentlyContinue -ErrorVariable err
            }
            finally {
                $env:PSMCPKB_API_KEY = $previous
            }
            $err | Should -Not -BeNullOrEmpty
            Should -Invoke Start-McpServer -Times 0
        }
    }

    It 'restarts OAuth servers with the stored OAuth settings and without an API key' {
        InModuleScope PSMcpKnowledgeBase {
            Mock Get-McpServerState {
                [pscustomobject]@{ knowledgeBase = 'Srv'; kbPath = 'x'; port = 7103; listenAddress = '*'; authRequired = $true; apiKeyRequired = $false
                    oauthIssuer = 'https://idp.example.com'; oauthAudience = @('a', 'api://a'); oauthScope = 'api://a/s'; Status = 'Stopped'; StateFile = 'x' }
            }
            Mock Remove-Item { }
            Mock Start-McpServer { }
            $previous = $env:PSMCPKB_API_KEY
            $env:PSMCPKB_API_KEY = $null
            try {
                Restart-McpServer -Port 7103
            }
            finally {
                $env:PSMCPKB_API_KEY = $previous
            }
            Should -Invoke Start-McpServer -Times 1 -Exactly -ParameterFilter {
                $OAuthIssuer -eq 'https://idp.example.com' -and ($OAuthAudience -join ',') -eq 'a,api://a' -and $OAuthScope -eq 'api://a/s' -and -not $ApiKey
            }
        }
    }

    It 'writes an error when no server matches' {
        Restart-McpServer -Port 7199 -ErrorAction SilentlyContinue -ErrorVariable err
        $err | Should -Not -BeNullOrEmpty
    }
}
