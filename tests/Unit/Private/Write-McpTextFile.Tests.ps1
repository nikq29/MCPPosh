BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Write-McpTextFile' {
    It 'writes UTF-8 without BOM, creates folders and replaces existing files' {
        InModuleScope MCPPosh -Parameters @{ Home = $script:TestHome } {
            param($Home)
            $file = Join-Path $Home 'deep/folder/text.md'
            Write-McpTextFile -Path $file -Content 'first'
            Write-McpTextFile -Path $file -Content "second $([char]0x00E4)"
            $bytes = [System.IO.File]::ReadAllBytes($file)
            $bytes[0] | Should -Not -Be 0xEF
            [System.Text.Encoding]::UTF8.GetString($bytes) | Should -Be "second $([char]0x00E4)"
            @(Get-ChildItem (Split-Path $file) -Filter '*.tmp' -Force).Count | Should -Be 0
        }
    }

    It 'writes empty files' {
        InModuleScope MCPPosh -Parameters @{ Home = $script:TestHome } {
            param($Home)
            $file = Join-Path $Home 'empty.md'
            Write-McpTextFile -Path $file -Content ''
            (Get-Item $file).Length | Should -Be 0
        }
    }
}
