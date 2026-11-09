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

Describe 'Get-McpManifestStamp' {
    It 'changes when the manifest changes' {
        InModuleScope MCPPosh {
            $kb = Resolve-McpKnowledgeBase -KnowledgeBase Kb
            $before = Get-McpManifestStamp -KbPath $kb.Path
            $before | Should -Match '^\d+-\d+$'
            Start-Sleep -Milliseconds 20
            Add-McpDocument -KnowledgeBase Kb -Title 'New' -Content 'new' | Out-Null
            Get-McpManifestStamp -KbPath $kb.Path | Should -Not -Be $before
        }
    }

    It 'returns 0 when there is no manifest' {
        InModuleScope MCPPosh -Parameters @{ Files = $script:Files } { param($Files) Get-McpManifestStamp -KbPath $Files | Should -Be '0' }
    }
}
