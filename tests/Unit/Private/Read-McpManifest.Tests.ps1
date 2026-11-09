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

Describe 'Read-McpManifest' {
    It 'reads the manifest of a knowledge base' {
        InModuleScope MCPPosh {
            $manifest = Read-McpManifest -KbPath (Resolve-McpKnowledgeBase -KnowledgeBase Kb).Path
            $manifest.documents.Count | Should -Be 1
            $manifest.revision | Should -Be 1
        }
    }

    It 'returns an empty manifest when the file is missing' {
        InModuleScope MCPPosh -Parameters @{ Home = $script:TestHome } {
            param($Home)
            $manifest = Read-McpManifest -KbPath (Join-Path $Home 'no-kb')
            $manifest.revision | Should -Be 0
            @($manifest.documents).Count | Should -Be 0
        }
    }
}
