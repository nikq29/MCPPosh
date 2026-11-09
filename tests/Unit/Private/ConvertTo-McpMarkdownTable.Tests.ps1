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

Describe 'ConvertTo-McpMarkdownTable' {
    It 'creates a table with header separator and pads short rows' {
        InModuleScope MCPPosh {
            $table = ConvertTo-McpMarkdownTable -Rows @([string[]]@('Name', 'Role'), [string[]]@('Anna'))
            $lines = $table.TrimEnd() -split "`r?`n"
            $lines[0] | Should -Be '| Name | Role |'
            $lines[1] | Should -Be '| --- | --- |'
            $lines[2] | Should -Be '| Anna |  |'
        }
    }

    It 'returns an empty string for no rows' {
        InModuleScope MCPPosh { ConvertTo-McpMarkdownTable -Rows @() | Should -Be '' }
    }
}
