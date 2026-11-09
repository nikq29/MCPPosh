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

Describe 'Write-McpDocumentIndex' {
    It 'writes the chunks of a document to the index file' {
        InModuleScope MCPPosh {
            $kb = Resolve-McpKnowledgeBase -KnowledgeBase Kb
            Write-McpDocumentIndex -KbPath $kb.Path -Id 'manual-1' -Content "# A`n`nAlpha text`n`n## B`n`nBeta text" -Title 'Manual'
            $index = Read-McpJsonFile -Path (Get-McpDocumentPath -KbPath $kb.Path -Id 'manual-1').Index
            $index.id | Should -Be 'manual-1'
            $index.chunks.Count | Should -Be 2
            $index.chunks[1].heading | Should -Be 'A > B'
            $index.chunks[0].tf.manual | Should -Be 1
        }
    }
}
