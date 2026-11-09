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

Describe 'ConvertTo-McpKnowledgeBaseObject' {
    It 'summarizes documents, characters, tags and revision' {
        InModuleScope MCPPosh {
            $object = ConvertTo-McpKnowledgeBaseObject -KnowledgeBase (Resolve-McpKnowledgeBase -KnowledgeBase Kb)
            $object.PSObject.TypeNames | Should -Contain 'MCPPosh.KnowledgeBase'
            $object.Documents | Should -Be 1
            $object.Characters | Should -BeGreaterThan 10
            $object.Tags | Should -Be @('setup')
            $object.Revision | Should -Be 1
        }
    }
}
