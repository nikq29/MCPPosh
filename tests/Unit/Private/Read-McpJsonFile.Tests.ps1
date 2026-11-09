BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Read-McpJsonFile' {
    It 'reads and parses a JSON file' {
        InModuleScope MCPPosh -Parameters @{ Home = $script:TestHome } {
            param($Home)
            $file = Join-Path $Home 'data.json'
            Set-Content -Path $file -Value '{"name":"value"}'
            (Read-McpJsonFile -Path $file).name | Should -Be 'value'
        }
    }

    It 'returns $null for missing and empty files' {
        InModuleScope MCPPosh -Parameters @{ Home = $script:TestHome } {
            param($Home)
            Read-McpJsonFile -Path (Join-Path $Home 'missing.json') | Should -BeNullOrEmpty
            $empty = Join-Path $Home 'empty.json'
            Set-Content -Path $empty -Value ''
            Read-McpJsonFile -Path $empty | Should -BeNullOrEmpty
        }
    }
}
