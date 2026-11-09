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

Describe 'ConvertTo-McpMarkdown' {
    It 'selects the converter by extension and returns a normalized result' {
        InModuleScope MCPPosh -Parameters @{ Files = $script:Files } {
            param($Files)
            $path = Join-Path $Files 'page.md'
            Set-Content -Path $path -Value "# Page`n`nText"
            $result = ConvertTo-McpMarkdown -Path $path
            $result.Format | Should -Be 'Markdown'
            $result.Title | Should -Be 'Page'
            , $result.Tags | Should -BeOfType [object[]]
        }
    }

    It 'uses the file name as title and supports -Format' {
        InModuleScope MCPPosh -Parameters @{ Files = $script:Files } {
            param($Files)
            $path = Join-Path $Files 'export.dat'
            Set-Content -Path $path -Value 'plain'
            $result = ConvertTo-McpMarkdown -Path $path -Format Text
            $result.Title | Should -Be 'export'
            $result.Format | Should -Be 'Text'
        }
    }

    It 'accepts string and object results from converters' {
        InModuleScope MCPPosh -Parameters @{ Files = $script:Files } {
            param($Files)
            $path = Join-Path $Files 'item.objx'
            Set-Content -Path $path -Value 'x'
            $script:McpConverters.Add([pscustomobject]@{ Name = 'Obj'; Extensions = @('.objx'); ScriptBlock = { [pscustomobject]@{ Content = 'object content'; Title = 'Obj Title' } }; Builtin = $false })
            try {
                $result = ConvertTo-McpMarkdown -Path $path
                $result.Content | Should -Be 'object content'
                $result.Title | Should -Be 'Obj Title'
            }
            finally {
                Initialize-McpConverterRegistry
            }
        }
    }

    It 'throws for binary files without converter' {
        InModuleScope MCPPosh -Parameters @{ Files = $script:Files } {
            param($Files)
            $binary = Join-Path $Files 'blob.bin'
            [System.IO.File]::WriteAllBytes($binary, [byte[]](0, 1, 2, 0))
            { ConvertTo-McpMarkdown -Path $binary } | Should -Throw '*No converter*'
        }
    }
}
