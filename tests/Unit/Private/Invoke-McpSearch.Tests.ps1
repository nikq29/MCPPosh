BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    $script:Files = Join-Path $script:TestHome 'files'
    New-Item -ItemType Directory -Path $script:Files -Force | Out-Null
    New-McpKnowledgeBase -Name Kb | Out-Null
    Add-McpDocument -KnowledgeBase Kb -Title 'VPN Runbook' -Tags vpn -Content "# VPN Runbook`n`n## Connection drops`n`nRestart the vpnagent service when the connection drops.`n`n## Certificates`n`nRenew the client certificate every year." | Out-Null
    Add-McpDocument -KnowledgeBase Kb -Title 'Deployment' -Tags devops -Content "# Deployment`n`n## Rollback`n`nRedeploy the previous image to roll back a release." | Out-Null
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Invoke-McpSearch' {
    It 'ranks the most relevant chunk first' {
        InModuleScope MCPPosh {
            $index = Get-McpSearchIndex -KbPath (Resolve-McpKnowledgeBase -KnowledgeBase Kb).Path
            $results = @(Invoke-McpSearch -Index $index -Query 'connection drops vpnagent')
            $results[0].Heading | Should -Be 'VPN Runbook > Connection drops'
            $results[0].Score | Should -BeGreaterThan 0
        }
    }

    It 'expands prefixes, filters by tag and limits chunks per document' {
        InModuleScope MCPPosh {
            $index = Get-McpSearchIndex -KbPath (Resolve-McpKnowledgeBase -KnowledgeBase Kb).Path
            (Invoke-McpSearch -Index $index -Query 'certif')[0].Heading | Should -Match 'Certificates'
            Invoke-McpSearch -Index $index -Query 'rollback' -Tags vpn | Should -BeNullOrEmpty
            @(Invoke-McpSearch -Index $index -Query 'vpn restart certificate connection' -MaxPerDocument 1).Count | Should -Be 1
        }
    }

    It 'returns nothing for stop words and unknown terms' {
        InModuleScope MCPPosh {
            $index = Get-McpSearchIndex -KbPath (Resolve-McpKnowledgeBase -KnowledgeBase Kb).Path
            Invoke-McpSearch -Index $index -Query 'the and' | Should -BeNullOrEmpty
            Invoke-McpSearch -Index $index -Query 'xyzzy' | Should -BeNullOrEmpty
        }
    }
}
