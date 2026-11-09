BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    $script:Files = Join-Path $script:TestHome 'files'
    New-Item -ItemType Directory -Path $script:Files -Force | Out-Null
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Initialize-McpConverterRegistry' {
    It 'registers the built-in converters and removes custom ones' {
        InModuleScope MCPPosh {
            $script:McpConverters.Add([pscustomobject]@{ Name = 'Custom'; Extensions = @('.cst'); ScriptBlock = { 'x' }; Builtin = $false })
            Initialize-McpConverterRegistry
            $script:McpConverters.Count | Should -Be 10
            @($script:McpConverters | Where-Object { -not $_.Builtin }).Count | Should -Be 0
            ($script:McpConverters | Where-Object Name -EQ 'Code').Extensions | Should -Contain '.ps1'
        }
    }
}
