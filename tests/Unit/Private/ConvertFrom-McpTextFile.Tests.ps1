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

Describe 'ConvertFrom-McpTextFile' {
    It 'returns the file content unchanged' {
        InModuleScope MCPPosh -Parameters @{ Files = $script:Files } {
            param($Files)
            $path = Join-Path $Files 'notes.txt'
            [System.IO.File]::WriteAllText($path, "line 1`nline 2")
            (ConvertFrom-McpTextFile -Path $path).Content | Should -Be "line 1`nline 2"
        }
    }
}
