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

Describe 'Set-McpDocumentProperty' {
    It 'changes title and tags and rebuilds the index for new titles' {
        InModuleScope MCPPosh -Parameters @{ Id = $script:Doc.Id } {
            param($Id)
            $kb = Resolve-McpKnowledgeBase -KnowledgeBase Kb
            $record = Set-McpDocumentProperty -KnowledgeBase $kb -Id $Id -Title 'Setup Handbook' -Tags b, a
            $record.title | Should -Be 'Setup Handbook'
            $record.tags | Should -Be @('a', 'b')
            (Get-Content -Raw (Get-McpDocumentPath -KbPath $kb.Path -Id $Id).Index) | Should -Match 'handbook'
        }
    }

    It 'throws for unknown documents' {
        InModuleScope MCPPosh {
            { Set-McpDocumentProperty -KnowledgeBase (Resolve-McpKnowledgeBase -KnowledgeBase Kb) -Id 'missing' -Title 'x' } | Should -Throw '*was not found*'
        }
    }
}
