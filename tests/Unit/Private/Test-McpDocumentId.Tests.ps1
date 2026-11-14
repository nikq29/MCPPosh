BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Test-McpDocumentId' {
    It 'accepts ids created by New-McpDocumentId' {
        InModuleScope MCPPosh {
            Test-McpDocumentId -Id 'install-guide-1a2b3c' | Should -BeTrue
            Test-McpDocumentId -Id (New-McpDocumentId -Title 'Grüße aus Köln: Installation!') | Should -BeTrue
        }
    }

    It 'rejects the id <Id>' -ForEach @(
        @{ Id = '' }
        @{ Id = '..' }
        @{ Id = '../secret' }
        @{ Id = '../../outside/secret' }
        @{ Id = 'a/b' }
        @{ Id = 'a\b' }
        @{ Id = '/etc/secret' }
        @{ Id = 'C:\temp\secret' }
        @{ Id = '\\server\share\secret' }
        @{ Id = 'doc.md' }
        @{ Id = "doc`n" }
        @{ Id = ('a' * 129) }
    ) {
        InModuleScope MCPPosh -Parameters @{ Id = $Id } {
            param($Id)
            Test-McpDocumentId -Id $Id | Should -BeFalse
        }
    }
}
