BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:TestHome = Initialize-McpTestEnvironment -Name documents
    $script:Docs = Join-Path $script:TestHome 'docs'
    New-Item -ItemType Directory -Path (Join-Path $script:Docs 'sub') -Force | Out-Null
    Set-Content -Path (Join-Path $script:Docs 'install.md') -Value "# Installation`n`nInstalliere das Paket mit winget."
    Set-Content -Path (Join-Path $script:Docs 'sub/faq.md') -Value "# FAQ`n`nHäufige Fragen zur Lizenz."
    Set-Content -Path (Join-Path $script:Docs 'notes.txt') -Value 'Lose Notizen'
    New-Item -ItemType Directory -Path (Join-Path $script:Docs '.git') -Force | Out-Null
    Set-Content -Path (Join-Path $script:Docs '.git/config.md') -Value '# should be ignored'
}

AfterAll {
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Knowledge base management' {
    It 'creates, lists, updates and removes knowledge bases' {
        $kb = New-McpKnowledgeBase -Name Team -Description 'Team docs'
        $kb.Name | Should -Be 'Team'
        $kb.Documents | Should -Be 0
        Test-Path (Join-Path $env:MCPPOSH_HOME 'knowledgebases/Team/manifest.json') | Should -BeTrue

        (Get-McpKnowledgeBase -Name 'Te*').Name | Should -Contain 'Team'
        { New-McpKnowledgeBase -Name Team } | Should -Throw '*already exists*'

        Set-McpKnowledgeBase -Name Team -Description 'Neue Beschreibung'
        (Get-McpKnowledgeBase -Name Team).Description | Should -Be 'Neue Beschreibung'

        Remove-McpKnowledgeBase -Name Team -Confirm:$false
        Get-McpKnowledgeBase -Name Team -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'rejects invalid names' {
        { New-McpKnowledgeBase -Name 'bad name!' } | Should -Throw
    }

    It 'supports knowledge bases at a custom path' {
        $path = Join-Path $script:TestHome 'share/Shared'
        $kb = New-McpKnowledgeBase -Name Shared -Path $path
        $kb.Path | Should -Be ([System.IO.Path]::GetFullPath($path))
        Add-McpDocument -KnowledgeBase $path -Title 'Geteilt' -Content 'Inhalt auf dem Share' | Out-Null
        (Get-McpDocument -KnowledgeBase $path).Title | Should -Be 'Geteilt'
    }

    It 'creates the Default knowledge base on first use' {
        Add-McpDocument -Title 'Erste Notiz' -Content 'Hallo' | Out-Null
        (Get-McpKnowledgeBase -Name Default).Documents | Should -Be 1
    }

    It 'fails for unknown non-default knowledge bases' {
        { Get-McpDocument -KnowledgeBase DoesNotExist } | Should -Throw '*New-McpKnowledgeBase*'
    }
}

Describe 'Adding and managing documents' {
    BeforeAll {
        New-McpKnowledgeBase -Name Docs -Description 'Testdoku' | Out-Null
    }

    It 'imports a folder recursively and skips .git' {
        $added = Add-McpDocument -Path $script:Docs -Recurse -KnowledgeBase Docs -Tags handbook
        $added.Count | Should -Be 3
        $added.Title | Should -Contain 'Installation'
        $added.Title | Should -Contain 'FAQ'
        $added.Title | Should -Not -Contain 'should be ignored'
        ($added | Where-Object Title -EQ 'FAQ').Tags | Should -Be @('handbook')
    }

    It 'honors -Include and pipeline input from Get-ChildItem' {
        New-McpKnowledgeBase -Name Filtered | Out-Null
        $added = Get-ChildItem -Path $script:Docs -Recurse -File | Where-Object FullName -NotMatch '\.git' |
            Add-McpDocument -KnowledgeBase Filtered -Include '*.md'
        $added.Count | Should -Be 2
        $added.Format | Sort-Object -Unique | Should -Be 'Markdown'
    }

    It 'updates instead of duplicating when the same file is added again' {
        $before = @(Get-McpDocument -KnowledgeBase Docs).Count
        $again = Add-McpDocument -Path (Join-Path $script:Docs 'install.md') -KnowledgeBase Docs
        @(Get-McpDocument -KnowledgeBase Docs).Count | Should -Be $before
        $again.Tags | Should -Be @('handbook') -Because 'tags are kept when -Tags is not specified'
    }

    It 'stores inline content and updates it by title' {
        $first = Add-McpDocument -KnowledgeBase Docs -Title 'VPN Tipp' -Content 'Version 1' -Tags vpn
        $second = Add-McpDocument -KnowledgeBase Docs -Title 'VPN Tipp' -Content 'Version 2'
        $second.Id | Should -Be $first.Id
        (Get-McpDocument -KnowledgeBase Docs -Id $first.Id -IncludeContent).Content | Should -Match 'Version 2'
        $second.SourceType | Should -Be 'Inline'
    }

    It 'filters documents by id, title, tag, format and source type' {
        (Get-McpDocument -KnowledgeBase Docs -Title 'FA*').Title | Should -Be 'FAQ'
        (Get-McpDocument -KnowledgeBase Docs -Tag vpn).Title | Should -Be 'VPN Tipp'
        @(Get-McpDocument -KnowledgeBase Docs -Format Text).Count | Should -Be 1
        @(Get-McpDocument -KnowledgeBase Docs -SourceType Inline).Count | Should -Be 1
        $faq = Get-McpDocument -KnowledgeBase Docs -Title FAQ
        (Get-McpDocument -KnowledgeBase Docs -Id $faq.Id).Title | Should -Be 'FAQ'
        $faq.Uri | Should -Be "mcpposh://Docs/documents/$($faq.Id)"
        $faq.Summary | Should -Match 'Lizenz'
    }

    It 'changes title, tags and content with Set-McpDocument' {
        $doc = Get-McpDocument -KnowledgeBase Docs -Title FAQ
        $doc | Set-McpDocument -Title 'Häufige Fragen' -AddTags faq -RemoveTags handbook
        $updated = Get-McpDocument -KnowledgeBase Docs -Id $doc.Id
        $updated.Title | Should -Be 'Häufige Fragen'
        $updated.Tags | Should -Be @('faq')

        $result = Set-McpDocument -KnowledgeBase Docs -Id $doc.Id -Content '# FAQ`n`nNeuer Inhalt' -PassThru
        $result.Title | Should -Be 'Häufige Fragen'
        (Get-McpDocument -KnowledgeBase Docs -Id $doc.Id -IncludeContent).Content | Should -Match 'Neuer Inhalt'
    }

    It 're-imports changed source files with Update-McpDocument' {
        $file = Join-Path $script:Docs 'install.md'
        $doc = Get-McpDocument -KnowledgeBase Docs -Title Installation
        Update-McpDocument -KnowledgeBase Docs -Id $doc.Id | Should -BeNullOrEmpty -Because 'the source did not change'

        Set-Content -Path $file -Value "# Installation`n`nInstalliere das Paket mit Chocolatey."
        $updated = Update-McpDocument -KnowledgeBase Docs -All
        $updated.Id | Should -Be $doc.Id
        (Get-McpDocument -KnowledgeBase Docs -Id $doc.Id -IncludeContent).Content | Should -Match 'Chocolatey'
    }

    It 'warns about or removes documents whose source file is gone' {
        $file = Join-Path $script:Docs 'temp.md'
        Set-Content -Path $file -Value '# Temporär'
        $doc = Add-McpDocument -KnowledgeBase Docs -Path $file
        Remove-Item $file
        Update-McpDocument -KnowledgeBase Docs -Id $doc.Id -WarningVariable warnings -WarningAction SilentlyContinue
        $warnings | Should -Not -BeNullOrEmpty
        Update-McpDocument -KnowledgeBase Docs -Id $doc.Id -RemoveMissing
        Get-McpDocument -KnowledgeBase Docs -Id $doc.Id -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'removes documents including their files' {
        $doc = Add-McpDocument -KnowledgeBase Docs -Title 'Wegwerf' -Content 'weg damit'
        $doc | Remove-McpDocument -Confirm:$false
        Get-McpDocument -KnowledgeBase Docs -Id $doc.Id -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Test-Path (Join-Path $env:MCPPOSH_HOME "knowledgebases/Docs/documents/$($doc.Id).md") | Should -BeFalse
        Test-Path (Join-Path $env:MCPPOSH_HOME "knowledgebases/Docs/index/$($doc.Id).json") | Should -BeFalse
    }

    It 'imports web pages with the HTML converter' {
        InModuleScope MCPPosh {
            Mock Invoke-WebRequest {
                Set-Content -LiteralPath $OutFile -Value '<html><head><title>Online Doku</title></head><body><h1>API</h1><p>Der Endpunkt lautet /v1/items.</p></body></html>'
                [pscustomobject]@{ Headers = @{ 'Content-Type' = 'text/html; charset=utf-8' } }
            }
            $doc = Add-McpDocument -KnowledgeBase Docs -Url 'https://example.com/docs/api' -Tags online
            $doc.Title | Should -Be 'Online Doku'
            $doc.Format | Should -Be 'Html'
            $doc.SourceType | Should -Be 'Url'
            $doc.Source | Should -Be 'https://example.com/docs/api'
            (Get-McpDocument -KnowledgeBase Docs -Id $doc.Id -IncludeContent).Content | Should -Match '/v1/items'
        }
    }

    It 'rejects non-http URLs' {
        { Add-McpDocument -KnowledgeBase Docs -Url 'file:///etc/passwd' -ErrorAction Stop } | Should -Throw '*http*'
    }

    It 'bumps the manifest revision on every change' {
        $before = (Get-McpKnowledgeBase -Name Docs).Revision
        Add-McpDocument -KnowledgeBase Docs -Title 'Rev' -Content 'a' | Out-Null
        (Get-McpKnowledgeBase -Name Docs).Revision | Should -BeGreaterThan $before
    }

    It 'supports -WhatIf without changing anything' {
        $before = @(Get-McpDocument -KnowledgeBase Docs).Count
        Add-McpDocument -KnowledgeBase Docs -Title 'WhatIf' -Content 'nope' -WhatIf
        @(Get-McpDocument -KnowledgeBase Docs).Count | Should -Be $before
    }
}
