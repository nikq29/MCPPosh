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

Describe 'Update-McpServerIndex' {
    It 'reloads the index and description when the manifest changes' {
        InModuleScope MCPPosh -Parameters @{ Context = $script:Context } {
            param($Context)
            $first = Update-McpServerIndex -Context $Context -Force
            $first.Documents.Count | Should -Be 2
            (Update-McpServerIndex -Context $Context) | Should -Be $first -Because 'the file system is checked at most once per second'
            Set-McpKnowledgeBase -Name Proto -Description 'Changed description'
            Add-McpDocument -KnowledgeBase Proto -Title 'New' -Content 'brand new' | Out-Null
            $reloaded = Update-McpServerIndex -Context $Context -Force
            $reloaded.Documents.Count | Should -Be 3
            $Context.KnowledgeBase.Description | Should -Be 'Changed description'
            Get-Content -Raw $Context.LogPath | Should -Match 'Knowledge base reloaded'
        }
    }
}
