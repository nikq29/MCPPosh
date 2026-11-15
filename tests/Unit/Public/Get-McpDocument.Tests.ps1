BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/PSMcpKnowledgeBase.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'PSMcpKnowledgeBase'
    New-McpKnowledgeBase -Name Docs | Out-Null
    Add-McpDocument -KnowledgeBase Docs -Title 'FAQ' -Content "# FAQ`n`nQuestions about licensing." -Tags faq | Out-Null
    Add-McpDocument -KnowledgeBase Docs -Title 'VPN tip' -Content 'Restart the agent.' -Tags vpn | Out-Null
    $textFile = Join-Path $script:TestHome 'notes.txt'
    Set-Content -Path $textFile -Value 'Plain notes'
    Add-McpDocument -KnowledgeBase Docs -Path $textFile | Out-Null
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpDocument' {
    It 'returns all documents' {
        @(Get-McpDocument -KnowledgeBase Docs).Count | Should -Be 3
    }

    It 'filters by title, tag, format and source type' {
        (Get-McpDocument -KnowledgeBase Docs -Title 'FA*').Title | Should -Be 'FAQ'
        (Get-McpDocument -KnowledgeBase Docs -Tag vpn).Title | Should -Be 'VPN tip'
        @(Get-McpDocument -KnowledgeBase Docs -Format Text).Count | Should -Be 1
        @(Get-McpDocument -KnowledgeBase Docs -SourceType Inline).Count | Should -Be 2
    }

    It 'returns a document by id with summary, uri and content' {
        $faq = Get-McpDocument -KnowledgeBase Docs -Title FAQ
        $doc = Get-McpDocument -KnowledgeBase Docs -Id $faq.Id -IncludeContent
        $doc.Uri | Should -Be "psmcpkb://Docs/documents/$($faq.Id)"
        $doc.Summary | Should -Match 'licensing'
        $doc.Content | Should -Match '# FAQ'
        $doc.PSObject.TypeNames | Should -Contain 'PSMcpKnowledgeBase.Document'
    }

    It 'writes an error for unknown ids and fails for unknown knowledge bases' {
        Get-McpDocument -KnowledgeBase Docs -Id missing -ErrorAction SilentlyContinue -ErrorVariable err
        $err | Should -Not -BeNullOrEmpty
        { Get-McpDocument -KnowledgeBase DoesNotExist } | Should -Throw '*New-McpKnowledgeBase*'
    }
}
