BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    New-McpKnowledgeBase -Name Kb | Out-Null
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Save-McpManifest' {
    It 'increments the revision and sets the updated timestamp' {
        InModuleScope MCPPosh {
            $kb = Resolve-McpKnowledgeBase -KnowledgeBase Kb
            $manifest = Read-McpManifest -KbPath $kb.Path
            $before = [long]$manifest.revision
            Save-McpManifest -KbPath $kb.Path -Manifest $manifest
            $after = Read-McpManifest -KbPath $kb.Path
            $after.revision | Should -Be ($before + 1)
            $after.updated | Should -Match 'Z$'
        }
    }
}
