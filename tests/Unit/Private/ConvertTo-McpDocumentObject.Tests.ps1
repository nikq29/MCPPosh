BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/PSMcpKnowledgeBase.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'PSMcpKnowledgeBase'
    New-McpKnowledgeBase -Name Kb | Out-Null
    $script:Doc = Add-McpDocument -KnowledgeBase Kb -Title 'Install Guide' -Content "# Install`n`nInstall the **package** with winget." -Tags setup
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'ConvertTo-McpDocumentObject' {
    It 'converts a manifest record to a document object' {
        InModuleScope PSMcpKnowledgeBase {
            $kb = Resolve-McpKnowledgeBase -KnowledgeBase Kb
            $record = (Read-McpManifest -KbPath $kb.Path).documents[0]
            $object = ConvertTo-McpDocumentObject -Record $record -KnowledgeBase $kb -IncludeContent
            $object.PSObject.TypeNames | Should -Contain 'PSMcpKnowledgeBase.Document'
            $object.Title | Should -Be 'Install Guide'
            $object.Tags | Should -Be @('setup')
            $object.Updated | Should -BeOfType [datetime]
            $object.Uri | Should -Be "psmcpkb://Kb/documents/$($record.id)"
            $object.Content | Should -Match 'winget'
        }
    }
}
