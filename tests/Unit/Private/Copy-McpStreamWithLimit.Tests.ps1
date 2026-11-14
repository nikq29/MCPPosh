BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Copy-McpStreamWithLimit' {
    It 'copies a stream up to the limit and returns the number of bytes' {
        InModuleScope MCPPosh {
            $source = [System.IO.MemoryStream]::new([byte[]](1..100))
            $target = [System.IO.MemoryStream]::new()
            Copy-McpStreamWithLimit -Source $source -Destination $target -MaxBytes 100 | Should -Be 100
            $target.ToArray() | Should -Be ([byte[]](1..100))
        }
    }

    It 'throws when more bytes arrive than allowed, regardless of declared sizes' {
        InModuleScope MCPPosh {
            $source = [System.IO.MemoryStream]::new([byte[]]::new(200000))
            { Copy-McpStreamWithLimit -Source $source -Destination ([System.IO.MemoryStream]::new()) -MaxBytes 100000 -Description 'test data' } |
                Should -Throw '*test data exceeds the limit of 100000 bytes*'
        }
    }
}
