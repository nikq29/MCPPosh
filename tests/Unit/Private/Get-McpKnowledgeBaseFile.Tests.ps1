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

Describe 'Get-McpKnowledgeBaseFile' {
    It 'lists metadata, manifest, documents and index files with relative paths' {
        InModuleScope MCPPosh {
            $files = @(Get-McpKnowledgeBaseFile -KbPath (Resolve-McpKnowledgeBase -KnowledgeBase Kb).Path)
            $files.RelativePath | Should -Contain 'knowledgebase.json'
            $files.RelativePath | Should -Contain 'manifest.json'
            @($files | Where-Object RelativePath -Like 'documents/*.md').Count | Should -Be 1
            @($files | Where-Object RelativePath -Like 'index/*.json').Count | Should -Be 1
            $files.RelativePath | Should -Not -Contain '.lock'
        }
    }
}
