<#
    End-to-end tests of the document cmdlets against the built module: import every built-in format from files,
    folders, inline content and a local web server, filter, edit, refresh, search and remove documents, and use
    custom converters. No mocks.
#>
BeforeDiscovery {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:FormatCases = @(Get-McpTestFixtureFormat | ForEach-Object { @{ Format = $_ } })
}

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment -Name documents
    $script:Files = Join-Path -Path $script:TestHome -ChildPath 'files'
    New-Item -ItemType Directory -Path $script:Files -Force | Out-Null
    $script:Web = Start-McpTestWebServer -Root (Join-Path -Path $script:TestHome -ChildPath 'web')

    function Write-TestFile {
        param([string] $Path, [string] $Content)
        $null = New-Item -ItemType Directory -Path (Split-Path -Path $Path -Parent) -Force
        [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
        $Path
    }
}

AfterAll {
    if ($script:Web) { Stop-McpTestWebServer -Server $script:Web }
    Get-McpDocumentConverter | Where-Object { -not $_.Builtin } | ForEach-Object { Unregister-McpDocumentConverter -Name $_.Name }
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Importing every built-in format' {
    BeforeAll {
        New-McpKnowledgeBase -Name Formats | Out-Null
    }

    It 'has an integration fixture for every built-in converter' {
        @(Get-McpDocumentConverter | Where-Object Builtin | ForEach-Object Name | Sort-Object) |
            Should -Be @(Get-McpTestFixtureFormat | Sort-Object)
    }

    It 'imports a <Format> file and finds it by its content' -ForEach $FormatCases {
        if ($Format -eq 'Pdf' -and -not (Test-McpTestPdfSupport)) {
            Set-ItResult -Skipped -Because 'neither PSWritePDF nor pdftotext is installed'
            return
        }
        $fixture = New-McpTestFixture -Format $Format -Directory (Join-Path $script:Files 'formats')
        $doc = Add-McpDocument -KnowledgeBase Formats -Path $fixture.Path -Tags fixture
        $doc.Format | Should -Be $Format
        $doc.SourceType | Should -Be 'File'
        Split-Path -Path $doc.Source -Leaf | Should -Be (Split-Path -Path $fixture.Path -Leaf)
        $doc.Chars | Should -BeGreaterThan 0
        $top = Search-McpDocument -KnowledgeBase Formats -Query $fixture.Keyword -Top 1
        $top.DocumentId | Should -Be $doc.Id
        "$($top.Heading) $($top.Text)" | Should -Match $fixture.Keyword
    }
}

Describe 'Adding documents' {
    BeforeAll {
        New-McpKnowledgeBase -Name Docs | Out-Null
    }

    It 'imports a folder recursively with include and exclude patterns' {
        $tree = Join-Path -Path $script:Files -ChildPath 'tree'
        Write-TestFile -Path (Join-Path $tree 'network.md') -Content "# Network`n`nThe core switch is SW-CORE-01." | Out-Null
        Write-TestFile -Path (Join-Path $tree 'sub/storage.md') -Content "# Storage`n`nThe NAS is called NAS-02." | Out-Null
        Write-TestFile -Path (Join-Path $tree 'sub/draft-old.md') -Content '# Old draft' | Out-Null
        Write-TestFile -Path (Join-Path $tree 'sub/notes.txt') -Content 'Text notes are not included.' | Out-Null

        $flat = @(Add-McpDocument -KnowledgeBase Docs -Path $tree -Include '*.md' -Tags flat)
        $flat.Title | Should -Be @('Network')

        $docs = @(Add-McpDocument -KnowledgeBase Docs -Path $tree -Recurse -Include '*.md' -Exclude 'draft-*' -Tags infrastructure)
        @($docs.Title | Sort-Object) | Should -Be @('Network', 'Storage')
        $docs | ForEach-Object { $_.Tags | Should -Contain 'infrastructure' }
        Get-McpDocument -KnowledgeBase Docs -Title 'Old draft' | Should -BeNullOrEmpty
    }

    It 'overrides title, tags and format of an imported file' {
        $path = Write-TestFile -Path (Join-Path $script:Files 'release.txt') -Content "# Release 2.0`n`n- New search ranking"
        $doc = Add-McpDocument -KnowledgeBase Docs -Path $path -Title 'Release notes' -Tags release, notes -Format Markdown
        $doc.Title | Should -Be 'Release notes'
        $doc.Format | Should -Be 'Markdown'
        $doc.Tags | Should -Be @('notes', 'release')
    }

    It 'adds inline content' {
        $doc = Add-McpDocument -KnowledgeBase Docs -Title 'Wi-Fi' -Content "# Wi-Fi`n`nThe guest network is called CONTOSO-GUEST." -Tags network
        $doc.SourceType | Should -Be 'Inline'
        $doc.Format | Should -Be 'Markdown'
        (Search-McpDocument -KnowledgeBase Docs -Query 'guest network').DocumentId | Should -Contain $doc.Id
    }

    It 'imports web pages and online documents by URL' {
        Write-TestFile -Path (Join-Path $script:Web.Root 'guide/page.html') -Content '<html><head><title>VPN guide</title></head><body><h1>VPN</h1><p>Connect to vpn.contoso.example. See <a href="faq.html">the FAQ</a>.</p></body></html>' | Out-Null
        Write-TestFile -Path (Join-Path $script:Web.Root 'readme.md') -Content "# Readme`n`nThe API base address is api.contoso.example." | Out-Null
        Write-TestFile -Path (Join-Path $script:Web.Root 'phones.csv') -Content "Name,Extension`nService desk,4711" | Out-Null

        $page = Add-McpDocument -KnowledgeBase Docs -Url "$($script:Web.Uri)guide/page.html" -Tags web
        $page.SourceType | Should -Be 'Url'
        $page.Format | Should -Be 'Html'
        $page.Title | Should -Be 'VPN guide'
        $content = (Get-McpDocument -KnowledgeBase Docs -Id $page.Id -IncludeContent).Content
        $content | Should -Match 'vpn\.contoso\.example'
        $content | Should -Match ([regex]::Escape("$($script:Web.Uri)guide/faq.html"))

        (Add-McpDocument -KnowledgeBase Docs -Url "$($script:Web.Uri)readme.md").Format | Should -Be 'Markdown'
        $csv = Add-McpDocument -KnowledgeBase Docs -Url "$($script:Web.Uri)phones.csv" -Title 'Phone list'
        $csv.Format | Should -Be 'Csv'
        $csv.Title | Should -Be 'Phone list'
        (Search-McpDocument -KnowledgeBase Docs -Query 'service desk extension' -Top 1).DocumentId | Should -Be $csv.Id
    }
}

Describe 'Finding and editing documents' {
    BeforeAll {
        New-McpKnowledgeBase -Name Edit | Out-Null
        $script:Backup = Add-McpDocument -KnowledgeBase Edit -Title 'Backup' -Content "# Backup`n`nThe nightly backup runs at 02:00." -Tags ops, backup
        $script:Phone = Add-McpDocument -KnowledgeBase Edit -Title 'Phone list' -Content 'Service desk: 4711' -Tags contacts
        $csvPath = Write-TestFile -Path (Join-Path $script:Files 'edit/servers.csv') -Content "Name,Role`nSRV-01,File server"
        $script:Servers = Add-McpDocument -KnowledgeBase Edit -Path $csvPath -Tags ops
    }

    It 'filters documents by id, title, tag, format and source type' {
        (Get-McpDocument -KnowledgeBase Edit).Count | Should -Be 3
        (Get-McpDocument -KnowledgeBase Edit -Id $script:Backup.Id).Title | Should -Be 'Backup'
        (Get-McpDocument -KnowledgeBase Edit -Title 'Phone*').Id | Should -Be $script:Phone.Id
        @((Get-McpDocument -KnowledgeBase Edit -Tag ops).Title | Sort-Object) | Should -Be @('Backup', 'servers.csv')
        (Get-McpDocument -KnowledgeBase Edit -Format Csv).Id | Should -Be $script:Servers.Id
        (Get-McpDocument -KnowledgeBase Edit -SourceType File).Id | Should -Be $script:Servers.Id
        @(Get-McpDocument -KnowledgeBase Edit -SourceType Inline).Count | Should -Be 2
        (Get-McpDocument -KnowledgeBase Edit -Id $script:Backup.Id).PSObject.Properties.Name | Should -Not -Contain 'Content'
        (Get-McpDocument -KnowledgeBase Edit -Id $script:Backup.Id -IncludeContent).Content | Should -Match 'nightly backup'
    }

    It 'changes title and tags' {
        Set-McpDocument -KnowledgeBase Edit -Id $script:Phone.Id -Title 'Phone directory' | Should -BeNullOrEmpty
        (Get-McpDocument -KnowledgeBase Edit -Id $script:Phone.Id).Title | Should -Be 'Phone directory'

        (Set-McpDocument -KnowledgeBase Edit -Id $script:Phone.Id -Tags contacts, phone -PassThru).Tags | Should -Be @('contacts', 'phone')
        (Set-McpDocument -KnowledgeBase Edit -Id $script:Phone.Id -AddTags support -PassThru).Tags | Should -Be @('contacts', 'phone', 'support')
        (Set-McpDocument -KnowledgeBase Edit -Id $script:Phone.Id -RemoveTags phone -PassThru).Tags | Should -Be @('contacts', 'support')
        (Search-McpDocument -KnowledgeBase Edit -Query 'service desk' -Tag support).DocumentId | Should -Contain $script:Phone.Id
    }

    It 'replaces the content and updates the search index' {
        $updated = Set-McpDocument -KnowledgeBase Edit -Id $script:Backup.Id -Content "# Backup`n`nThe nightly backup now runs at 03:30 with Veeam." -PassThru
        $updated.Title | Should -Be 'Backup'
        (Search-McpDocument -KnowledgeBase Edit -Query 'veeam' -Top 1).DocumentId | Should -Be $script:Backup.Id
        (Get-McpDocument -KnowledgeBase Edit -Id $script:Backup.Id -IncludeContent).Content | Should -Not -Match '02:00'
    }

    It 'searches with a result limit and tag filter' {
        Add-McpDocument -KnowledgeBase Edit -Title 'Restore' -Content "# Restore`n`nRestore a backup from the backup console." -Tags ops | Out-Null
        @(Search-McpDocument -KnowledgeBase Edit -Query 'backup').Count | Should -BeGreaterThan 1
        @(Search-McpDocument -KnowledgeBase Edit -Query 'backup' -Top 1).Count | Should -Be 1
        Search-McpDocument -KnowledgeBase Edit -Query 'backup' -Tag contacts | Should -BeNullOrEmpty
    }

    It 'removes documents from the knowledge base and the index' {
        Remove-McpDocument -KnowledgeBase Edit -Id $script:Phone.Id -Confirm:$false
        Get-McpDocument -KnowledgeBase Edit -Id $script:Phone.Id -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        (Search-McpDocument -KnowledgeBase Edit -Query 'service desk').DocumentId | Should -Not -Contain $script:Phone.Id
    }
}

Describe 'Refreshing documents from their source' {
    BeforeAll {
        New-McpKnowledgeBase -Name Refresh | Out-Null
        $script:SourceFile = Write-TestFile -Path (Join-Path $script:Files 'refresh/policy.md') -Content "# Password policy`n`nPasswords expire after 90 days."
        $script:Policy = Add-McpDocument -KnowledgeBase Refresh -Path $script:SourceFile
        $script:OtherFile = Write-TestFile -Path (Join-Path $script:Files 'refresh/legacy.md') -Content "# Legacy`n`nThe legacy ERP is retired."
        $script:Legacy = Add-McpDocument -KnowledgeBase Refresh -Path $script:OtherFile
        Write-TestFile -Path (Join-Path $script:Web.Root 'status.html') -Content '<html><head><title>Status</title></head><body><p>All systems operational.</p></body></html>' | Out-Null
        $script:Status = Add-McpDocument -KnowledgeBase Refresh -Url "$($script:Web.Uri)status.html"
    }

    It 're-imports a changed source file by id' {
        Update-McpDocument -KnowledgeBase Refresh -Id $script:Policy.Id | Should -BeNullOrEmpty
        Write-TestFile -Path $script:SourceFile -Content "# Password policy`n`nPasswords expire after 180 days." | Out-Null
        $updated = Update-McpDocument -KnowledgeBase Refresh -Id $script:Policy.Id
        $updated.Id | Should -Be $script:Policy.Id
        (Get-McpDocument -KnowledgeBase Refresh -Id $script:Policy.Id -IncludeContent).Content | Should -Match '180 days'
    }

    It 're-imports unchanged files with -Force and discards manual edits' {
        Set-McpDocument -KnowledgeBase Refresh -Id $script:Policy.Id -Content 'Edited by hand.' | Out-Null
        Update-McpDocument -KnowledgeBase Refresh -Id $script:Policy.Id | Should -BeNullOrEmpty
        (Update-McpDocument -KnowledgeBase Refresh -Id $script:Policy.Id -Force).Id | Should -Be $script:Policy.Id
        (Get-McpDocument -KnowledgeBase Refresh -Id $script:Policy.Id -IncludeContent).Content | Should -Match '180 days'
    }

    It 'downloads URL sources again' {
        Write-TestFile -Path (Join-Path $script:Web.Root 'status.html') -Content '<html><head><title>Status</title></head><body><p>Maintenance on Saturday.</p></body></html>' | Out-Null
        (Update-McpDocument -KnowledgeBase Refresh -Id $script:Status.Id).Id | Should -Be $script:Status.Id
        (Get-McpDocument -KnowledgeBase Refresh -Id $script:Status.Id -IncludeContent).Content | Should -Match 'Maintenance on Saturday'
    }

    It 'refreshes all documents and removes documents whose source file is gone only with -RemoveMissing' {
        Remove-Item -LiteralPath $script:OtherFile
        Update-McpDocument -KnowledgeBase Refresh -All -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null
        $warnings | Should -Match 'legacy\.md'
        (Get-McpDocument -KnowledgeBase Refresh).Id | Should -Contain $script:Legacy.Id

        Update-McpDocument -KnowledgeBase Refresh -All -RemoveMissing -Confirm:$false | Out-Null
        (Get-McpDocument -KnowledgeBase Refresh).Id | Should -Not -Contain $script:Legacy.Id
        (Get-McpDocument -KnowledgeBase Refresh).Id | Should -Contain $script:Policy.Id
    }
}

Describe 'Custom converters' {
    BeforeAll {
        New-McpKnowledgeBase -Name Converters | Out-Null
        $script:NoteFile = Write-TestFile -Path (Join-Path $script:Files 'converters/meeting.note') -Content "title: Weekly meeting`nThe weekly meeting moved to Thursday."
    }

    It 'lists built-in converters by name and extension' {
        (Get-McpDocumentConverter -Name Pdf).Extensions | Should -Contain '.pdf'
        (Get-McpDocumentConverter -Extension .yml).Name | Should -Be 'Yaml'
        (Get-McpDocumentConverter -Extension ps1).Name | Should -Be 'Code'
        @(Get-McpDocumentConverter -Name '*').Count | Should -BeGreaterOrEqual 10
    }

    It 'imports files with a registered converter' {
        $converter = Register-McpDocumentConverter -Name Note -Extension .note -ScriptBlock {
            param($Path)
            $lines = Get-Content -LiteralPath $Path
            @{ Title = ($lines[0] -replace '^title:\s*', ''); Content = ($lines | Select-Object -Skip 1) -join "`n"; Tags = @('note') }
        }
        $converter.Builtin | Should -BeFalse
        (Get-McpDocumentConverter -Extension .note).Name | Should -Be 'Note'

        $doc = Add-McpDocument -KnowledgeBase Converters -Path $script:NoteFile
        $doc.Format | Should -Be 'Note'
        $doc.Title | Should -Be 'Weekly meeting'
        $doc.Tags | Should -Contain 'note'
        (Search-McpDocument -KnowledgeBase Converters -Query 'thursday' -Top 1).DocumentId | Should -Be $doc.Id
    }

    It 'replaces a registered converter only with -Force' {
        { Register-McpDocumentConverter -Name Note -Extension .note -ScriptBlock { param($Path) 'x' } } | Should -Throw '*-Force*'
        Register-McpDocumentConverter -Name Note -Extension .note -Force -ScriptBlock {
            param($Path)
            @{ Title = 'Meeting (v2)'; Content = (Get-Content -LiteralPath $Path -Raw).ToUpperInvariant() }
        } | Out-Null
        $doc = Add-McpDocument -KnowledgeBase Converters -Path $script:NoteFile
        $doc.Title | Should -Be 'Meeting (v2)'
        (Get-McpDocument -KnowledgeBase Converters -Id $doc.Id -IncludeContent).Content | Should -Match 'THURSDAY'
    }

    It 'removes a registered converter' {
        Unregister-McpDocumentConverter -Name Note
        Get-McpDocumentConverter -Name Note | Should -BeNullOrEmpty
        Get-McpDocumentConverter -Extension .note | Where-Object Name -EQ 'Note' | Should -BeNullOrEmpty
    }
}
