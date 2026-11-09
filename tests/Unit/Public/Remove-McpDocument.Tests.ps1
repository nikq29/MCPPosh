BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    New-McpKnowledgeBase -Name Docs | Out-Null
    $script:Doc = Add-McpDocument -KnowledgeBase Docs -Title 'Disposable' -Content 'remove me'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Remove-McpDocument' {
    It 'keeps the document with -WhatIf' {
        Remove-McpDocument -KnowledgeBase Docs -Id $script:Doc.Id -WhatIf
        Get-McpDocument -KnowledgeBase Docs -Id $script:Doc.Id | Should -Not -BeNullOrEmpty
    }

    It 'removes the document and its files' {
        $script:Doc | Remove-McpDocument -Confirm:$false
        Get-McpDocument -KnowledgeBase Docs -Id $script:Doc.Id -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Test-Path (Join-Path $env:MCPPOSH_HOME "knowledgebases/Docs/documents/$($script:Doc.Id).md") | Should -BeFalse
        Test-Path (Join-Path $env:MCPPOSH_HOME "knowledgebases/Docs/index/$($script:Doc.Id).json") | Should -BeFalse
    }

    It 'writes an error for unknown documents' {
        Remove-McpDocument -KnowledgeBase Docs -Id missing -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable err
        $err | Should -Not -BeNullOrEmpty
    }
}
