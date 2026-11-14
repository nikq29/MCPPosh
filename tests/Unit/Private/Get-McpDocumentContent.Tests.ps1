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

Describe 'Get-McpDocumentContent (invalid ids)' {
    It 'never reads files outside the knowledge base' {
        InModuleScope MCPPosh -Parameters @{ TestHome = $script:TestHome } {
            param($TestHome)
            $outside = Join-Path $TestHome 'outside-content'
            New-Item -ItemType Directory -Path $outside -Force | Out-Null
            Set-Content -Path (Join-Path $outside 'secret.md') -Value 'TOP SECRET'
            $kbPath = (Resolve-McpKnowledgeBase -KnowledgeBase Kb).Path
            Get-McpDocumentContent -KbPath $kbPath -Id (Join-Path $outside 'secret') | Should -BeNullOrEmpty
            Get-McpDocumentContent -KbPath $kbPath -Id '../../../outside-content/secret' | Should -BeNullOrEmpty
        }
    }
}
