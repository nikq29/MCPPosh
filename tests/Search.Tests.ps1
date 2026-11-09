BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:TestHome = Initialize-McpTestEnvironment -Name search
    New-McpKnowledgeBase -Name Search -Description 'Suchtests' | Out-Null

    $runbook = @'
# VPN Runbook

Allgemeine Hinweise zum VPN-Zugang für Mitarbeitende.

## Verbindung bricht ab

Wenn die VPN-Verbindung abbricht, starte den Dienst vpnagent neu und prüfe die Firewall.

## Zertifikat erneuern

Das Client-Zertifikat läuft jährlich ab. Beantrage ein neues Zertifikat im Self-Service-Portal.
'@
    $deploy = @'
# Deployment Guide

## Pipeline

The deployment pipeline builds the container image and pushes it to the registry.

## Rollback

To roll back a release, redeploy the previous image tag with the pipeline.
'@
    Add-McpDocument -KnowledgeBase Search -Title 'VPN Runbook' -Content $runbook -Tags vpn, runbook | Out-Null
    Add-McpDocument -KnowledgeBase Search -Title 'Deployment Guide' -Content $deploy -Tags devops | Out-Null
}

AfterAll {
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Tokenizer' {
    It 'lowercases, folds diacritics, removes stop words and stems' {
        $tokens = InModuleScope MCPPosh { Get-McpToken -Text 'Die Server-Konfigurationen für Größe' }
        $tokens | Should -Contain 'serv'
        $tokens | Should -Contain 'konfiguration'
        $tokens | Should -Contain 'gros' -Because 'ö is folded to o and the suffix e is stripped'
        $tokens | Should -Not -Contain 'die'
        $tokens | Should -Not -Contain 'fur'
    }

    It 'stems singular and plural forms to the same token' {
        InModuleScope MCPPosh {
            (Get-McpToken -Text 'servers')[0] | Should -Be (Get-McpToken -Text 'server')[0]
            (Get-McpToken -Text 'Dokumente')[0] | Should -Be (Get-McpToken -Text 'Dokumenten')[0]
        }
    }
}

Describe 'Chunking' {
    It 'splits by headings and keeps the heading path' {
        $chunks = InModuleScope MCPPosh {
            Split-McpMarkdownSection -Content "# A`n`nText A`n`n## B`n`nText B`n`n``````md`n# not a heading`n```````n`n# C`n`nText C"
        }
        $chunks.Count | Should -Be 3
        $chunks[0].heading | Should -Be 'A'
        $chunks[1].heading | Should -Be 'A > B'
        $chunks[1].text | Should -Match 'not a heading'
        $chunks[2].heading | Should -Be 'C'
    }

    It 'splits long sections into chunks below the size limit' {
        $chunks = InModuleScope MCPPosh {
            $paragraphs = 1..40 | ForEach-Object { "Absatz $_ " + ('wort ' * 20) }
            Split-McpMarkdownSection -Content ("# Lang`n`n" + ($paragraphs -join "`n`n")) -MaxChars 500
        }
        $chunks.Count | Should -BeGreaterThan 5
        $chunks | ForEach-Object { $_.text.Length | Should -BeLessOrEqual 500 }
        $chunks | ForEach-Object { $_.heading | Should -Be 'Lang' }
    }
}

Describe 'Search-McpDocument' {
    It 'finds the most relevant section first' {
        $results = Search-McpDocument -KnowledgeBase Search -Query 'VPN Verbindung abgebrochen'
        $results[0].Title | Should -Be 'VPN Runbook'
        $results[0].Heading | Should -Be 'VPN Runbook > Verbindung bricht ab'
        $results[0].Text | Should -Match 'vpnagent'
    }

    It 'ranks English content for English queries' {
        $results = Search-McpDocument -KnowledgeBase Search -Query 'how to rollback a release'
        $results[0].Heading | Should -Be 'Deployment Guide > Rollback'
    }

    It 'expands prefixes of unknown terms' {
        $results = Search-McpDocument -KnowledgeBase Search -Query 'zertifik'
        $results[0].Heading | Should -Match 'Zertifikat'
    }

    It 'filters by tag' {
        $results = Search-McpDocument -KnowledgeBase Search -Query 'pipeline' -Tag vpn
        $results | Should -BeNullOrEmpty
        (Search-McpDocument -KnowledgeBase Search -Query 'pipeline' -Tag devops)[0].Title | Should -Be 'Deployment Guide'
    }

    It 'limits the number of results and returns snippets' {
        $results = @(Search-McpDocument -KnowledgeBase Search -Query 'pipeline image registry release' -Top 1)
        $results.Count | Should -Be 1
        $results[0].Snippet | Should -Not -BeNullOrEmpty
    }

    It 'returns nothing for queries without known terms' {
        Search-McpDocument -KnowledgeBase Search -Query 'xyzzy' | Should -BeNullOrEmpty
        Search-McpDocument -KnowledgeBase Search -Query 'der die das' | Should -BeNullOrEmpty
    }

    It 'sees documents added after the index was loaded' {
        Search-McpDocument -KnowledgeBase Search -Query 'Kaffeemaschine' | Should -BeNullOrEmpty
        Add-McpDocument -KnowledgeBase Search -Title 'Büro' -Content 'Die Kaffeemaschine steht im zweiten Stock.' | Out-Null
        (Search-McpDocument -KnowledgeBase Search -Query 'Kaffeemaschine')[0].Title | Should -Be 'Büro'
    }

    It 'rebuilds a missing index file from the document content' {
        $doc = Get-McpDocument -KnowledgeBase Search -Title 'Büro'
        $indexFile = Join-Path $env:MCPPOSH_HOME "knowledgebases/Search/index/$($doc.Id).json"
        Remove-Item $indexFile
        InModuleScope MCPPosh { $script:McpIndexCache.Clear() }
        (Search-McpDocument -KnowledgeBase Search -Query 'Kaffeemaschine')[0].Title | Should -Be 'Büro'
        Test-Path $indexFile | Should -BeTrue
    }
}
