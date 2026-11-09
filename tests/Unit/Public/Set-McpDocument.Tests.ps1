BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    New-McpKnowledgeBase -Name Docs | Out-Null
    $script:Doc = Add-McpDocument -KnowledgeBase Docs -Title 'FAQ' -Content "# FAQ`n`nOld content" -Tags handbook
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Set-McpDocument' {
    It 'changes title and tags incrementally through the pipeline' {
        Get-McpDocument -KnowledgeBase Docs -Id $script:Doc.Id | Set-McpDocument -Title 'Questions' -AddTags faq -RemoveTags handbook
        $updated = Get-McpDocument -KnowledgeBase Docs -Id $script:Doc.Id
        $updated.Title | Should -Be 'Questions'
        $updated.Tags | Should -Be @('faq')
    }

    It 'replaces all tags with -Tags' {
        Set-McpDocument -KnowledgeBase Docs -Id $script:Doc.Id -Tags a, b
        (Get-McpDocument -KnowledgeBase Docs -Id $script:Doc.Id).Tags | Should -Be @('a', 'b')
    }

    It 'replaces the content and keeps the title' {
        $result = Set-McpDocument -KnowledgeBase Docs -Id $script:Doc.Id -Content "# FAQ`n`nNew content" -PassThru
        $result.Title | Should -Be 'Questions'
        (Get-McpDocument -KnowledgeBase Docs -Id $script:Doc.Id -IncludeContent).Content | Should -Match 'New content'
    }

    It 'writes an error for unknown documents' {
        Set-McpDocument -KnowledgeBase Docs -Id missing -Title x -ErrorAction SilentlyContinue -ErrorVariable err
        $err | Should -Not -BeNullOrEmpty
    }
}
