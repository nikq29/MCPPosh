BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpProcessStartTime' {
    It 'returns the start time of a running process and $null for missing processes' {
        InModuleScope MCPPosh {
            $value = Get-McpProcessStartTime -ProcessId $PID
            [datetime]::Parse($value).ToUniversalTime() | Should -BeLessThan ([datetime]::UtcNow.AddSeconds(1))
            Get-McpProcessStartTime -ProcessId 999999 | Should -BeNullOrEmpty
        }
    }
}
