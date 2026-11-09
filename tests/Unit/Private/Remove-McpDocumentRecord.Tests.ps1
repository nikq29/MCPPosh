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

Describe 'Remove-McpDocumentRecord' {
    It 'removes the record and the files of a document' {
        InModuleScope MCPPosh -Parameters @{ Id = $script:Doc.Id } {
            param($Id)
            $kb = Resolve-McpKnowledgeBase -KnowledgeBase Kb
            Remove-McpDocumentRecord -KnowledgeBase $kb -Id $Id
            @((Read-McpManifest -KbPath $kb.Path).documents).Count | Should -Be 0
            Test-Path (Get-McpDocumentPath -KbPath $kb.Path -Id $Id).Content | Should -BeFalse
        }
    }

    It 'throws for unknown documents' {
        InModuleScope MCPPosh {
            { Remove-McpDocumentRecord -KnowledgeBase (Resolve-McpKnowledgeBase -KnowledgeBase Kb) -Id 'missing' } | Should -Throw '*was not found*'
        }
    }
}
