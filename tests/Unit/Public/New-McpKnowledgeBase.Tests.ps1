BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'New-McpKnowledgeBase' {
    It 'creates a knowledge base in the MCPPosh home' {
        $kb = New-McpKnowledgeBase -Name Team -Description 'Team docs'
        $kb.Name | Should -Be 'Team'
        $kb.Description | Should -Be 'Team docs'
        $kb.Documents | Should -Be 0
        Test-Path (Join-Path $env:MCPPOSH_HOME 'knowledgebases/Team/manifest.json') | Should -BeTrue
        Test-Path (Join-Path $env:MCPPOSH_HOME 'knowledgebases/Team/documents') | Should -BeTrue
    }

    It 'refuses to overwrite an existing knowledge base' {
        { New-McpKnowledgeBase -Name Team } | Should -Throw '*already exists*'
    }

    It 'rejects invalid names' {
        { New-McpKnowledgeBase -Name 'bad name!' } | Should -Throw
    }

    It 'creates a knowledge base at a custom path' {
        $path = Join-Path $script:TestHome 'share/Shared'
        $kb = New-McpKnowledgeBase -Name Shared -Path $path
        $kb.Path | Should -Be ([System.IO.Path]::GetFullPath($path))
        Test-Path (Join-Path $path 'knowledgebase.json') | Should -BeTrue
    }

    It 'supports -WhatIf' {
        New-McpKnowledgeBase -Name WhatIfKb -WhatIf
        Test-Path (Join-Path $env:MCPPOSH_HOME 'knowledgebases/WhatIfKb') | Should -BeFalse
    }
}
