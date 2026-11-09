BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    New-McpKnowledgeBase -Name Search | Out-Null
    $runbook = @(
        '# VPN Runbook', '', 'General notes about VPN access.', ''
        '## Connection drops', '', 'When the VPN connection drops, restart the vpnagent service and check the firewall.', ''
        '## Renew certificate', '', 'The client certificate expires every year. Request a new certificate in the self-service portal.'
    ) -join "`n"
    $deployment = @(
        '# Deployment Guide', '', '## Pipeline', '', 'The deployment pipeline builds the container image and pushes it to the registry.', ''
        '## Rollback', '', 'To roll back a release, redeploy the previous image tag with the pipeline.'
    ) -join "`n"
    Add-McpDocument -KnowledgeBase Search -Title 'VPN Runbook' -Tags vpn -Content $runbook | Out-Null
    Add-McpDocument -KnowledgeBase Search -Title 'Deployment Guide' -Tags devops -Content $deployment | Out-Null
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Search-McpDocument' {
    It 'finds the most relevant section first' {
        $results = Search-McpDocument -KnowledgeBase Search -Query 'vpn connection dropped'
        $results[0].Heading | Should -Be 'VPN Runbook > Connection drops'
        $results[0].Text | Should -Match 'vpnagent'
        $results[0].PSObject.TypeNames | Should -Contain 'MCPPosh.SearchResult'
    }

    It 'filters by tag and limits the results' {
        Search-McpDocument -KnowledgeBase Search -Query 'pipeline' -Tag vpn | Should -BeNullOrEmpty
        @(Search-McpDocument -KnowledgeBase Search -Query 'pipeline image registry release' -Top 1).Count | Should -Be 1
    }

    It 'accepts queries from the pipeline' {
        ('rollback' | Search-McpDocument -KnowledgeBase Search)[0].Heading | Should -Be 'Deployment Guide > Rollback'
    }

    It 'sees documents added after the index was loaded' {
        Search-McpDocument -KnowledgeBase Search -Query 'espresso' | Should -BeNullOrEmpty
        Add-McpDocument -KnowledgeBase Search -Title 'Office' -Content 'The espresso machine is on the second floor.' | Out-Null
        (Search-McpDocument -KnowledgeBase Search -Query 'espresso')[0].Title | Should -Be 'Office'
    }
}
