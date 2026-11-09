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

Describe 'ConvertFrom-McpHtmlTable' {
    It 'converts header and data cells to a Markdown table' {
        InModuleScope MCPPosh {
            $table = ConvertFrom-McpHtmlTable -TableHtml '<table><tr><th>Code</th><th>Meaning</th></tr><tr><td>809</td><td><b>Port</b> blocked</td></tr></table>'
            $table | Should -Match '(?m)^\| Code \| Meaning \|$'
            $table | Should -Match '(?m)^\| 809 \| Port blocked \|$'
        }
    }

    It 'returns an empty string for tables without rows' {
        InModuleScope MCPPosh { ConvertFrom-McpHtmlTable -TableHtml '<table></table>' | Should -Be '' }
    }
}
