BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Test-McpServerProcess' {
    It 'checks process id and start time' {
        InModuleScope MCPPosh {
            $start = [System.Diagnostics.Process]::GetCurrentProcess().StartTime.ToUniversalTime().ToString('o')
            Test-McpServerProcess -ProcessId $PID -ProcessStartTime $start | Should -BeTrue
            Test-McpServerProcess -ProcessId $PID | Should -BeTrue
            Test-McpServerProcess -ProcessId $PID -ProcessStartTime '2000-01-01T00:00:00.0000000Z' | Should -BeFalse
            Test-McpServerProcess -ProcessId 999999 | Should -BeFalse
        }
    }
}

Describe 'Test-McpServerProcess (unverifiable identity)' {
    It 'does not confirm a process whose recorded start time cannot be read' {
        InModuleScope MCPPosh {
            Test-McpServerProcess -ProcessId $PID -ProcessStartTime 'not a date' | Should -BeFalse
        }
    }
}
