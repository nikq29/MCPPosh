BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'ConvertFrom-McpJson' {
    It 'parses objects into ordered dictionaries and keeps value types' {
        InModuleScope MCPPosh {
            $result = ConvertFrom-McpJson -Json '{"id":42,"name":"x","ratio":0.5,"ok":true,"none":null,"list":[1,"a"]}'
            $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
            $result.id | Should -BeOfType [long]
            $result.ratio | Should -BeOfType [double]
            $result.ok | Should -BeTrue
            $result.none | Should -BeNullOrEmpty
            $result.list | Should -Be @(1, 'a')
        }
    }

    It 'keeps date-like strings as strings' {
        InModuleScope MCPPosh {
            (ConvertFrom-McpJson -Json '{"q":"2025-06-18"}').q | Should -BeOfType [string]
        }
    }

    It 'tolerates comments and trailing commas and throws on invalid JSON' {
        InModuleScope MCPPosh {
            (ConvertFrom-McpJson -Json "{ // comment`n `"a`": 1, }").a | Should -Be 1
            { ConvertFrom-McpJson -Json '{not json' } | Should -Throw
        }
    }
}
