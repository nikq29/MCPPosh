BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'ConvertFrom-McpJsonElement' {
    It 'converts arrays, nested objects and empty arrays' {
        InModuleScope MCPPosh {
            $document = [System.Text.Json.JsonDocument]::Parse('{"a":[],"b":{"c":[true,false]}}')
            try { $result = ConvertFrom-McpJsonElement -Element $document.RootElement } finally { $document.Dispose() }
            , $result.a | Should -BeOfType [object[]]
            $result.a.Count | Should -Be 0
            $result.b.c | Should -Be @($true, $false)
        }
    }
}
