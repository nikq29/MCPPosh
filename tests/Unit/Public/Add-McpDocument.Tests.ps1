BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    New-McpKnowledgeBase -Name Docs | Out-Null
    $script:Docs = Join-Path $script:TestHome 'docs'
    New-Item -ItemType Directory -Path (Join-Path $script:Docs 'sub') -Force | Out-Null
    Set-Content -Path (Join-Path $script:Docs 'install.md') -Value "# Installation`n`nInstall the package with winget."
    Set-Content -Path (Join-Path $script:Docs 'sub/faq.md') -Value "# FAQ`n`nFrequently asked questions about licensing."
    Set-Content -Path (Join-Path $script:Docs 'notes.txt') -Value 'Loose notes'
    New-Item -ItemType Directory -Path (Join-Path $script:Docs '.git') -Force | Out-Null
    Set-Content -Path (Join-Path $script:Docs '.git/config.md') -Value '# should be ignored'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Add-McpDocument' {
    It 'imports a folder recursively and skips .git' {
        $added = Add-McpDocument -Path $script:Docs -Recurse -KnowledgeBase Docs -Tags handbook
        $added.Count | Should -Be 3
        $added.Title | Should -Contain 'Installation'
        $added.Title | Should -Not -Contain 'should be ignored'
        ($added | Where-Object Title -EQ 'FAQ').Tags | Should -Be @('handbook')
    }

    It 'honors -Include, -Exclude and pipeline input from Get-ChildItem' {
        New-McpKnowledgeBase -Name Filtered | Out-Null
        $added = Get-ChildItem -Path $script:Docs -Recurse -File | Where-Object FullName -NotMatch '\.git' |
            Add-McpDocument -KnowledgeBase Filtered -Include '*.md' -Exclude 'faq*'
        @($added).Count | Should -Be 1
        $added.Title | Should -Be 'Installation'
    }

    It 'updates instead of duplicating and keeps tags when -Tags is omitted' {
        $before = @(Get-McpDocument -KnowledgeBase Docs).Count
        $again = Add-McpDocument -Path (Join-Path $script:Docs 'install.md') -KnowledgeBase Docs
        @(Get-McpDocument -KnowledgeBase Docs).Count | Should -Be $before
        $again.Tags | Should -Be @('handbook')
    }

    It 'stores inline content and updates it by title' {
        $first = Add-McpDocument -KnowledgeBase Docs -Title 'VPN tip' -Content 'Version 1' -Tags vpn
        $second = Add-McpDocument -KnowledgeBase Docs -Title 'VPN tip' -Content 'Version 2'
        $second.Id | Should -Be $first.Id
        $second.SourceType | Should -Be 'Inline'
        (Get-McpDocument -KnowledgeBase Docs -Id $first.Id -IncludeContent).Content | Should -Match 'Version 2'
    }

    It 'converts inline HTML with -Format Html' {
        $doc = Add-McpDocument -KnowledgeBase Docs -Title 'Html note' -Content '<h1>Heading</h1><p>Body</p>' -Format Html
        $doc.Format | Should -Be 'Html'
        (Get-McpDocument -KnowledgeBase Docs -Id $doc.Id -IncludeContent).Content | Should -Match '# Heading'
    }

    It 'imports web pages with the HTML converter' {
        InModuleScope MCPPosh {
            Mock Invoke-WebRequest {
                Set-Content -LiteralPath $OutFile -Value '<html><head><title>Online docs</title></head><body><h1>API</h1><p>The endpoint is /v1/items.</p></body></html>'
                [pscustomobject]@{ Headers = @{ 'Content-Type' = 'text/html; charset=utf-8' } }
            }
            $doc = Add-McpDocument -KnowledgeBase Docs -Url 'https://example.com/docs/api' -Tags online
            $doc.Title | Should -Be 'Online docs'
            $doc.Format | Should -Be 'Html'
            $doc.SourceType | Should -Be 'Url'
            $doc.Source | Should -Be 'https://example.com/docs/api'
        }
    }

    It 'rejects non-http URLs' {
        { Add-McpDocument -KnowledgeBase Docs -Url 'file:///etc/passwd' -ErrorAction Stop } | Should -Throw '*http*'
    }

    It 'writes an error for missing paths and unsupported files' {
        Add-McpDocument -KnowledgeBase Docs -Path (Join-Path $script:TestHome 'missing.md') -ErrorAction SilentlyContinue -ErrorVariable missing
        $missing | Should -Not -BeNullOrEmpty
        $binary = Join-Path $script:TestHome 'blob.bin'
        [System.IO.File]::WriteAllBytes($binary, [byte[]](0, 1, 2, 0))
        Add-McpDocument -KnowledgeBase Docs -Path $binary -ErrorAction SilentlyContinue -ErrorVariable unsupported
        $unsupported | Should -Not -BeNullOrEmpty
    }

    It 'creates the Default knowledge base on first use' {
        Add-McpDocument -Title 'First note' -Content 'Hello' | Out-Null
        (Get-McpKnowledgeBase -Name Default).Documents | Should -Be 1
    }

    It 'does not change anything with -WhatIf' {
        $before = @(Get-McpDocument -KnowledgeBase Docs).Count
        Add-McpDocument -KnowledgeBase Docs -Title 'WhatIf' -Content 'nope' -WhatIf
        @(Get-McpDocument -KnowledgeBase Docs).Count | Should -Be $before
    }
}
