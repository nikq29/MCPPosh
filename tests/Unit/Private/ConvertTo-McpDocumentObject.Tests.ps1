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

Describe 'ConvertTo-McpDocumentObject' {
    It 'converts a manifest record to a document object' {
        InModuleScope MCPPosh {
            $kb = Resolve-McpKnowledgeBase -KnowledgeBase Kb
            $record = (Read-McpManifest -KbPath $kb.Path).documents[0]
            $object = ConvertTo-McpDocumentObject -Record $record -KnowledgeBase $kb -IncludeContent
            $object.PSObject.TypeNames | Should -Contain 'MCPPosh.Document'
            $object.Title | Should -Be 'Install Guide'
            $object.Tags | Should -Be @('setup')
            $object.Updated | Should -BeOfType [datetime]
            $object.Uri | Should -Be "mcpposh://Kb/documents/$($record.id)"
            $object.Content | Should -Match 'winget'
        }
    }
}
