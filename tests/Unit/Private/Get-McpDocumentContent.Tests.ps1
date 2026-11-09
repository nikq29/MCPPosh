BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    New-McpKnowledgeBase -Name Kb | Out-Null
    $script:Doc = Add-McpDocument -KnowledgeBase Kb -Title 'Install Guide' -Content "# Install`n`nInstall the **package** with winget." -Tags setup
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpDocumentContent' {
    It 'returns the Markdown content of a document' {
        InModuleScope MCPPosh -Parameters @{ Id = $script:Doc.Id } {
            param($Id)
            Get-McpDocumentContent -KbPath (Resolve-McpKnowledgeBase -KnowledgeBase Kb).Path -Id $Id | Should -Match 'winget'
        }
    }

    It 'returns $null for unknown documents' {
        InModuleScope MCPPosh {
            Get-McpDocumentContent -KbPath (Resolve-McpKnowledgeBase -KnowledgeBase Kb).Path -Id 'missing' | Should -BeNullOrEmpty
        }
    }
}
