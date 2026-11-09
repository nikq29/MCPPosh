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

Describe 'Split-McpTextBySize' {
    It 'packs paragraphs into chunks of limited size' {
        InModuleScope MCPPosh {
            $text = (1..10 | ForEach-Object { 'p' * 90 }) -join "`n`n"
            $chunks = Split-McpTextBySize -Text $text -MaxChars 200
            $chunks.Count | Should -Be 5
            $chunks | ForEach-Object { $_.Length | Should -BeLessOrEqual 200 }
        }
    }

    It 'splits long lines and hard-wraps single long words' {
        InModuleScope MCPPosh {
            $lines = Split-McpTextBySize -Text ((1..6 | ForEach-Object { 'l' * 60 }) -join "`n") -MaxChars 130
            $lines | ForEach-Object { $_.Length | Should -BeLessOrEqual 130 }
            $wrapped = Split-McpTextBySize -Text ('x' * 450) -MaxChars 200
            $wrapped.Count | Should -Be 3
        }
    }
}
