BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpUtcNow' {
    It 'returns the current UTC time in ISO 8601 format' {
        InModuleScope MCPPosh {
            $value = Get-McpUtcNow
            $value | Should -Match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$'
            ([datetime]::UtcNow - (ConvertTo-McpDateTime -Value $value).ToUniversalTime()).TotalSeconds | Should -BeLessThan 5
        }
    }
}
