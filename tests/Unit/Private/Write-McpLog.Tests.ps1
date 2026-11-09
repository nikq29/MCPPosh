BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Write-McpLog' {
    It 'appends timestamped lines to the log file' {
        InModuleScope MCPPosh -Parameters @{ Home = $script:TestHome } {
            param($Home)
            $context = [pscustomobject]@{ LogPath = (Join-Path $Home 'logs/test.log'); EchoLog = $false }
            Write-McpLog -Context $context -Message 'first'
            Write-McpLog -Context $context -Level ERROR -Message 'second'
            $lines = Get-Content $context.LogPath
            $lines.Count | Should -Be 2
            $lines[1] | Should -Match '^\d{4}-\d{2}-\d{2}T.*Z \[ERROR\] second$'
        }
    }

    It 'never fails when the log cannot be written' {
        InModuleScope MCPPosh {
            $context = [pscustomobject]@{ LogPath = '/proc/0/cannot/write.log'; EchoLog = $false }
            { Write-McpLog -Context $context -Message 'x' } | Should -Not -Throw
        }
    }
}
