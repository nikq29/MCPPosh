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

Describe 'ConvertFrom-McpCsvFile' {
    It 'converts semicolon separated files to a Markdown table' {
        InModuleScope MCPPosh -Parameters @{ Files = $script:Files } {
            param($Files)
            $path = Join-Path $Files 'contacts.csv'
            Set-Content -Path $path -Value "Name;Role`nAnna;Admin`nBen;Support"
            $result = ConvertFrom-McpCsvFile -Path $path
            $result.Content | Should -Match '(?m)^\| Name \| Role \|$'
            $result.Content | Should -Match '(?m)^\| Ben \| Support \|$'
        }
    }

    It 'reads TSV files and handles empty files' {
        InModuleScope MCPPosh -Parameters @{ Files = $script:Files } {
            param($Files)
            $tsv = Join-Path $Files 'data.tsv'
            Set-Content -Path $tsv -Value "A`tB`n1`t2"
            (ConvertFrom-McpCsvFile -Path $tsv).Content | Should -Match '(?m)^\| 1 \| 2 \|$'
            $empty = Join-Path $Files 'empty.csv'
            Set-Content -Path $empty -Value 'Header'
            (ConvertFrom-McpCsvFile -Path $empty).Content | Should -Match 'empty table'
        }
    }
}
