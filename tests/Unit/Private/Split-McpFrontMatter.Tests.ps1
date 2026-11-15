BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/PSMcpKnowledgeBase.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'PSMcpKnowledgeBase'
    $script:Files = Join-Path $script:TestHome 'files'
    New-Item -ItemType Directory -Path $script:Files -Force | Out-Null
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Split-McpFrontMatter' {
    It 'separates front matter with inline tag lists' {
        InModuleScope PSMcpKnowledgeBase {
            $result = Split-McpFrontMatter -Text "---`ntitle: `"Setup`"`ntags: [intern, setup]`n---`n# Setup"
            $result.Title | Should -Be 'Setup'
            $result.Tags | Should -Be @('intern', 'setup')
            $result.Body | Should -Be '# Setup'
        }
    }

    It 'reads keywords lists and leaves text without front matter unchanged' {
        InModuleScope PSMcpKnowledgeBase {
            (Split-McpFrontMatter -Text "---`nkeywords:`n  - a`n  - b`n---`nBody").Tags | Should -Be @('a', 'b')
            $plain = Split-McpFrontMatter -Text '# Just Markdown'
            $plain.Body | Should -Be '# Just Markdown'
            $plain.Title | Should -BeNullOrEmpty
        }
    }
}
