BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'ConvertTo-McpJson' {
    It 'serializes compact JSON and keeps single-element arrays' {
        InModuleScope MCPPosh {
            ConvertTo-McpJson -InputObject ([ordered]@{ a = @('x') }) -Compress | Should -Be '{"a":["x"]}'
            ConvertTo-McpJson -InputObject @('x') -Compress | Should -Be '["x"]'
        }
    }

    It 'produces indented JSON without -Compress' {
        InModuleScope MCPPosh {
            ConvertTo-McpJson -InputObject ([ordered]@{ a = 1 }) | Should -Match "`n"
        }
    }
}
