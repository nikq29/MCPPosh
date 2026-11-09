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

Describe 'Test-McpTextFile' {
    It 'detects text and binary files' {
        InModuleScope MCPPosh -Parameters @{ Files = $script:Files } {
            param($Files)
            $text = Join-Path $Files 'a.txt'
            Set-Content -Path $text -Value 'hello'
            $binary = Join-Path $Files 'a.bin'
            [System.IO.File]::WriteAllBytes($binary, [byte[]](1, 0, 2))
            Test-McpTextFile -Path $text | Should -BeTrue
            Test-McpTextFile -Path $binary | Should -BeFalse
        }
    }
}
