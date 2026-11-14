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

    It 'copies a complete stream when a timeout is set' {
        InModuleScope MCPPosh {
            $source = [System.IO.MemoryStream]::new([byte[]](1..100))
            $target = [System.IO.MemoryStream]::new()
            Copy-McpStreamWithLimit -Source $source -Destination $target -MaxBytes 100 -TimeoutSeconds 5 | Should -Be 100
            $target.ToArray() | Should -Be ([byte[]](1..100))
        }
    }

    It 'throws a TimeoutException when the source stops sending before the end' {
        InModuleScope MCPPosh {
            # A pipe whose writer sends a few bytes and then stays open: reads block like a stalled client.
            $writer = [System.IO.Pipes.AnonymousPipeServerStream]::new([System.IO.Pipes.PipeDirection]::Out)
            $reader = [System.IO.Pipes.AnonymousPipeClientStream]::new([System.IO.Pipes.PipeDirection]::In, $writer.ClientSafePipeHandle)
            Register-McpTestDisposeAfter -InputObject $writer -Seconds 15
            try {
                $writer.Write([byte[]](1..10), 0, 10)
                $writer.Flush()
                $watch = [System.Diagnostics.Stopwatch]::StartNew()
                $thrown = $null
                try {
                    $null = Copy-McpStreamWithLimit -Source $reader -Destination ([System.IO.MemoryStream]::new()) -MaxBytes 1000 -TimeoutSeconds 1 -Description 'request body'
                }
                catch {
                    $thrown = $_.Exception
                }
                $watch.Elapsed.TotalSeconds | Should -BeLessThan 10
                $thrown | Should -BeOfType [System.TimeoutException]
                $thrown.Message | Should -BeLike '*request body*1 second*'
            }
            finally {
                $writer.Dispose()
                $reader.Dispose()
            }
        }
    }
}
