BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Read-McpTextFile' {
    It 'reads UTF-8 text and removes a byte order mark' {
        InModuleScope MCPPosh -Parameters @{ Home = $script:TestHome } {
            param($Home)
            $file = Join-Path $Home 'bom.txt'
            [System.IO.File]::WriteAllText($file, "Gr$([char]0x00FC)n", [System.Text.UTF8Encoding]::new($true))
            Read-McpTextFile -Path $file | Should -Be "Gr$([char]0x00FC)n"
        }
    }
}
