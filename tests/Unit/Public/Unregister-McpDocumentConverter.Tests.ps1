BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Unregister-McpDocumentConverter' {
    It 'removes a custom converter' {
        Register-McpDocumentConverter -Name Temp -Extension .tmpx -ScriptBlock { 'x' } | Out-Null
        Unregister-McpDocumentConverter -Name Temp
        Get-McpDocumentConverter -Name Temp | Should -BeNullOrEmpty
    }

    It 'does not remove built-in converters' {
        { Unregister-McpDocumentConverter -Name Markdown -ErrorAction Stop } | Should -Throw
        Get-McpDocumentConverter -Name Markdown | Should -Not -BeNullOrEmpty
    }
}
