BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpDocumentPath' {
    It 'returns the content and index paths' {
        InModuleScope MCPPosh {
            $paths = Get-McpDocumentPath -KbPath '/kb' -Id 'doc-1'
            $paths.Content | Should -Be ([System.IO.Path]::Combine('/kb', 'documents', 'doc-1.md'))
            $paths.Index | Should -Be ([System.IO.Path]::Combine('/kb', 'index', 'doc-1.json'))
        }
    }
}
