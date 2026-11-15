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

Describe 'Remove-McpDocumentRecord (invalid ids)' {
    It 'removes records with invalid ids from the manifest without deleting files' {
        InModuleScope MCPPosh -Parameters @{ TestHome = $script:TestHome } {
            param($TestHome)
            $outside = Join-Path $TestHome 'outside-remove'
            New-Item -ItemType Directory -Path $outside -Force | Out-Null
            $victim = Join-Path $outside 'victim.md'
            Set-Content -Path $victim -Value 'keep me'
            $badId = Join-Path $outside 'victim'
            $kb = Resolve-McpKnowledgeBase -KnowledgeBase Kb
            $manifest = Read-McpManifest -KbPath $kb.Path
            $manifest['documents'] = @($manifest['documents']) + @([ordered]@{ id = $badId; title = 'evil' })
            Save-McpManifest -KbPath $kb.Path -Manifest $manifest

            Remove-McpDocumentRecord -KnowledgeBase $kb -Id $badId
            @((Read-McpManifest -KbPath $kb.Path).documents | Where-Object { $_.id -eq $badId }).Count | Should -Be 0
            Test-Path -LiteralPath $victim | Should -BeTrue
        }
    }
}
