BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/PSMcpKnowledgeBase.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'PSMcpKnowledgeBase'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Initialize-McpKnowledgeBaseFolder' {
    It 'creates the folders, metadata and an empty manifest' {
        InModuleScope PSMcpKnowledgeBase -Parameters @{ Home = $script:TestHome } {
            param($Home)
            $path = Join-Path $Home 'kb-init'
            Initialize-McpKnowledgeBaseFolder -Path $path -Name Init -Description 'Init test'
            foreach ($folder in 'documents', 'index', 'logs') { Test-Path (Join-Path $path $folder) | Should -BeTrue }
            (Read-McpJsonFile -Path (Join-Path $path 'knowledgebase.json')).description | Should -Be 'Init test'
            (Read-McpManifest -KbPath $path).revision | Should -Be 0
        }
    }

    It 'does not overwrite existing metadata' {
        InModuleScope PSMcpKnowledgeBase -Parameters @{ Home = $script:TestHome } {
            param($Home)
            $path = Join-Path $Home 'kb-init'
            Initialize-McpKnowledgeBaseFolder -Path $path -Name Other -Description 'Changed'
            (Read-McpJsonFile -Path (Join-Path $path 'knowledgebase.json')).name | Should -Be 'Init'
        }
    }
}
