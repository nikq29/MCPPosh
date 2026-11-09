BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'ConvertTo-McpShellArgument' {
    It 'leaves safe values unchanged and quotes others' {
        InModuleScope MCPPosh {
            ConvertTo-McpShellArgument -Value 'mcpposh-docs' | Should -Be 'mcpposh-docs'
            $quoted = ConvertTo-McpShellArgument -Value "Import-Module 'x'; Start"
            if ($IsWindows) { $quoted | Should -Be "`"Import-Module 'x'; Start`"" } else { $quoted | Should -Be "'Import-Module '\''x'\''; Start'" }
        }
    }
}
