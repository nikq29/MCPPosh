BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/PSMcpKnowledgeBase.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'PSMcpKnowledgeBase'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'ConvertTo-McpShellArgument' {
    It 'leaves safe values unchanged' {
        InModuleScope PSMcpKnowledgeBase {
            ConvertTo-McpShellArgument -Value 'psmcpkb-docs' | Should -Be 'psmcpkb-docs'
            ConvertTo-McpShellArgument -Value 'https://docs.example.com/mcp' -Shell PowerShell | Should -Be 'https://docs.example.com/mcp'
        }
    }

    It 'quotes values for POSIX shells' {
        InModuleScope PSMcpKnowledgeBase {
            ConvertTo-McpShellArgument -Value "Import-Module 'x'; Start" -Shell Posix | Should -Be "'Import-Module '\''x'\''; Start'"
            ConvertTo-McpShellArgument -Value 'a $(id) `b`' -Shell Posix | Should -Be "'a `$(id) ``b``'"
        }
    }

    It 'quotes values for PowerShell so that nothing is expanded' {
        InModuleScope PSMcpKnowledgeBase {
            ConvertTo-McpShellArgument -Value "Import-Module 'x'; Start" -Shell PowerShell | Should -Be "'Import-Module ''x''; Start'"
            $quoted = ConvertTo-McpShellArgument -Value 'C:\KB $(Get-Process) `n "x"' -Shell PowerShell
            $quoted | Should -Be "'C:\KB `$(Get-Process) ``n `"x`"'"
            # Parsing the quoted value as PowerShell yields the original string without running anything.
            $tokens = $null
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseInput("Write-Output $quoted", [ref]$tokens, [ref]$errors)
            $errors | Should -BeNullOrEmpty
            $ast.EndBlock.Statements[0].PipelineElements[0].CommandElements[1].Value | Should -Be 'C:\KB $(Get-Process) `n "x"'
        }
    }

    It 'escapes the curly quotes PowerShell also treats as single quotes' {
        InModuleScope PSMcpKnowledgeBase {
            $value = "C:\Users\Bob$([char]0x2019)s KB$([char]0x2018); Get-Process"
            $quoted = ConvertTo-McpShellArgument -Value $value -Shell PowerShell
            $tokens = $null
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseInput("Write-Output $quoted", [ref]$tokens, [ref]$errors)
            $errors | Should -BeNullOrEmpty
            $ast.EndBlock.Statements[0].PipelineElements[0].CommandElements[1].Value | Should -Be $value
        }
    }

    It 'uses PowerShell quoting on Windows and POSIX quoting elsewhere by default' {
        InModuleScope PSMcpKnowledgeBase {
            $expected = if ($IsWindows) { "'it''s'" } else { "'it'\''s'" }
            ConvertTo-McpShellArgument -Value "it's" | Should -Be $expected
        }
    }
}
