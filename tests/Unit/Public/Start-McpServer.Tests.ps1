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

Describe 'Start-McpServer' {
    It 'runs the stdio transport for Transport Stdio' {
        InModuleScope MCPPosh {
            Mock Start-McpStdioServer { }
            Start-McpServer -KnowledgeBase Srv -Transport Stdio -AllowWrite
            Should -Invoke Start-McpStdioServer -Times 1 -ParameterFilter { $Context.KnowledgeBase.Name -eq 'Srv' -and $Context.AllowWrite -and $Context.Transport -eq 'Stdio' }
        }
    }

    It 'runs the HTTP transport in the foreground with the API keys' {
        InModuleScope MCPPosh {
            Mock Start-McpHttpServer { }
            Start-McpServer -KnowledgeBase Srv -Port 5123 -ApiKey 'k1', 'k2' -Foreground
            Should -Invoke Start-McpHttpServer -Times 1 -ParameterFilter {
                $Port -eq 5123 -and $ListenAddress -eq 'localhost' -and ($ApiKeys -join ',') -eq 'k1,k2' -and $Context.LogPath -like '*server-5123.log'
            }
        }
    }

    It 'reads API keys from MCPPOSH_API_KEY' {
        InModuleScope MCPPosh {
            Mock Start-McpHttpServer { }
            $previous = $env:MCPPOSH_API_KEY
            $env:MCPPOSH_API_KEY = 'env-key-1, env-key-2'
            try {
                Start-McpServer -KnowledgeBase Srv -ListenAddress '*' -Foreground
            }
            finally {
                $env:MCPPOSH_API_KEY = $previous
            }
            Should -Invoke Start-McpHttpServer -Times 1 -ParameterFilter { ($ApiKeys -join ',') -eq 'env-key-1,env-key-2' }
        }
    }

    It 'requires an API key when listening on all interfaces' {
        $previous = $env:MCPPOSH_API_KEY
        $env:MCPPOSH_API_KEY = $null
        try {
            { Start-McpServer -KnowledgeBase Srv -ListenAddress '*' -Port 5999 -Foreground } | Should -Throw '*ApiKey*'
        }
        finally {
            $env:MCPPOSH_API_KEY = $previous
        }
    }

    It 'allows anonymous access only with -AllowAnonymous' {
        InModuleScope MCPPosh {
            Mock Start-McpHttpServer { }
            Start-McpServer -KnowledgeBase Srv -ListenAddress '*' -AllowAnonymous -Foreground
            Should -Invoke Start-McpHttpServer -Times 1 -ParameterFilter { $AllowAnonymous }
        }
    }

    It 'refuses to start a background server on a port that is in use' {
        InModuleScope MCPPosh {
            Mock Get-McpServerState { [pscustomobject]@{ port = 5124; Status = 'Running'; knowledgeBase = 'Other'; pid = 1 } }
            { Start-McpServer -KnowledgeBase Srv -Port 5124 } | Should -Throw '*already running*'
            Mock Get-McpServerState { }
            Mock Test-McpPortAvailable { $false }
            { Start-McpServer -KnowledgeBase Srv -Port 5125 } | Should -Throw '*already in use*'
        }
    }

    It 'does not start a process with -WhatIf' {
        InModuleScope MCPPosh {
            Mock Start-Process { throw 'must not be called' }
            Start-McpServer -KnowledgeBase Srv -Port (Get-McpFreePort) -WhatIf
            Should -Invoke Start-Process -Times 0
        }
    }

    It 'reports the errors of a background server that fails to start' {
        InModuleScope MCPPosh {
            Mock Start-Process {
                Set-Content -LiteralPath $RedirectStandardError -Value 'boom: listener failed'
                [System.Diagnostics.Process]::Start((Get-McpPwshPath), '-NoProfile -Command exit 1')
            }
            { Start-McpServer -KnowledgeBase Srv -Port (Get-McpFreePort) -StartTimeoutSeconds 5 } | Should -Throw '*boom: listener failed*'
        }
    }
}
