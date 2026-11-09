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

Describe 'Save-McpDocument' {
    It 'creates a document with content, index and manifest record' {
        InModuleScope MCPPosh {
            $kb = Resolve-McpKnowledgeBase -KnowledgeBase Kb
            $saved = Save-McpDocument -KnowledgeBase $kb -Title 'VPN' -Content "# VPN`n`nRestart the agent." -SourceType Inline -Tags vpn, ' ', vpn
            $saved.Created | Should -BeTrue
            $saved.Changed | Should -BeTrue
            $saved.Record.tags | Should -Be @('vpn')
            $paths = Get-McpDocumentPath -KbPath $kb.Path -Id $saved.Record.id
            Test-Path $paths.Content | Should -BeTrue
            Test-Path $paths.Index | Should -BeTrue
        }
    }

    It 'detects unchanged documents and updates changed ones' {
        InModuleScope MCPPosh {
            $kb = Resolve-McpKnowledgeBase -KnowledgeBase Kb
            $unchanged = Save-McpDocument -KnowledgeBase $kb -Title 'VPN' -Content "# VPN`n`nRestart the agent." -SourceType Inline -Tags vpn
            $unchanged.Changed | Should -BeFalse
            $changed = Save-McpDocument -KnowledgeBase $kb -Title 'VPN' -Content "# VPN`n`nRestart the service." -SourceType Inline -Tags vpn
            $changed.Changed | Should -BeTrue
            $changed.Created | Should -BeFalse
            $changed.Record.id | Should -Be $unchanged.Record.id
        }
    }

    It 'merges existing tags and throws for unknown ids' {
        InModuleScope MCPPosh {
            $kb = Resolve-McpKnowledgeBase -KnowledgeBase Kb
            (Save-McpDocument -KnowledgeBase $kb -Title 'VPN' -Content 'new' -SourceType Inline -Tags extra -MergeExistingTags).Record.tags | Should -Be @('extra', 'vpn')
            { Save-McpDocument -KnowledgeBase $kb -Id 'missing' -Title 'x' -Content 'x' } | Should -Throw '*was not found*'
        }
    }
}
