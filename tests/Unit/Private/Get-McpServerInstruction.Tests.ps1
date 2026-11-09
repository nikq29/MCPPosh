BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    New-McpKnowledgeBase -Name Proto -Description 'Protocol tests' | Out-Null
    Add-McpDocument -KnowledgeBase Proto -Title 'Backup' -Content "# Backup`n`nThe nightly backup runs at 02:00 with Veeam." -Tags ops | Out-Null
    Add-McpDocument -KnowledgeBase Proto -Title 'Onboarding' -Content ("# Onboarding`n`n" + ('New employees receive their laptop on the first day. ' * 40)) -Tags hr | Out-Null
    $script:Context = New-McpTestContext -KnowledgeBase Proto
    $script:WriteContext = New-McpTestContext -KnowledgeBase Proto -AllowWrite
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpServerInstruction' {
    It 'describes the knowledge base and the tools' {
        InModuleScope MCPPosh -Parameters @{ Context = $script:Context } {
            param($Context)
            $text = Get-McpServerInstruction -Context $Context
            $text | Should -Match "knowledge base 'Proto'"
            $text | Should -Match 'Protocol tests\.'
            $text | Should -Match 'search_documentation'
            $text | Should -Not -Match 'add_note'
        }
    }

    It 'mentions add_note with write access' {
        InModuleScope MCPPosh -Parameters @{ Context = $script:WriteContext } {
            param($Context)
            Get-McpServerInstruction -Context $Context | Should -Match 'add_note'
        }
    }
}
