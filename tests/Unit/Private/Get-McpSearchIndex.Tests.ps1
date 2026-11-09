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

Describe 'Get-McpSearchIndex' {
    It 'loads chunks and postings and caches the index' {
        InModuleScope MCPPosh {
            $kb = Resolve-McpKnowledgeBase -KnowledgeBase Kb
            $index = Get-McpSearchIndex -KbPath $kb.Path
            $index.Chunks.Count | Should -Be 3
            $index.Documents.Count | Should -Be 2
            $index.Postings.ContainsKey('vpnagent') | Should -BeTrue
            (Get-McpSearchIndex -KbPath $kb.Path) | Should -Be $index -Because 'the cached index is reused while the manifest is unchanged'
        }
    }

    It 'rebuilds missing or corrupt index files from the content' {
        InModuleScope MCPPosh {
            $kb = Resolve-McpKnowledgeBase -KnowledgeBase Kb
            $doc = (Read-McpManifest -KbPath $kb.Path).documents[0]
            $paths = Get-McpDocumentPath -KbPath $kb.Path -Id $doc.id
            Remove-Item $paths.Index
            $other = (Get-McpDocumentPath -KbPath $kb.Path -Id (Read-McpManifest -KbPath $kb.Path).documents[1].id).Index
            Set-Content -Path $other -Value '{corrupt'
            $index = Get-McpSearchIndex -KbPath $kb.Path -Force
            $index.Chunks.Count | Should -Be 3
            Test-Path $paths.Index | Should -BeTrue
        }
    }
}
