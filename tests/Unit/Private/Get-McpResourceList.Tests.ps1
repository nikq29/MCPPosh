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

Describe 'Get-McpResourceList' {
    It 'lists documents as resources' {
        $result = Invoke-McpTestMessage -KnowledgeBase Proto -Message @{ jsonrpc = '2.0'; id = 1; method = 'resources/list' }
        $result.result.resources.Count | Should -Be 2
        $result.result.resources[0].uri | Should -Match '^mcpposh://Proto/documents/'
        $result.result.resources[0].mimeType | Should -Be 'text/markdown'
        $result.result.resources[0].title | Should -Be 'Backup'
    }

    It 'rejects invalid cursors' {
        InModuleScope MCPPosh -Parameters @{ Context = $script:Context } {
            param($Context)
            { Get-McpResourceList -Context $Context -Params ([ordered]@{ cursor = 'abc' }) } | Should -Throw '*invalid cursor*'
            @((Get-McpResourceList -Context $Context -Params ([ordered]@{ cursor = '1' })).resources).Count | Should -Be 1
        }
    }
}
