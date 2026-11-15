<#
    End-to-end tests of the knowledge base cmdlets against the built module: create, list, update, export,
    import and remove knowledge bases on disk. No mocks.
#>
BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers/PSMcpKnowledgeBase.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment -Name kb
    $script:Work = Join-Path -Path $script:TestHome -ChildPath 'work'
    New-Item -ItemType Directory -Path $script:Work -Force | Out-Null
    $script:Archive = Join-Path -Path $script:Work -ChildPath 'archives/handbook.zip'

    function Get-DocumentSnapshot {
        param([string] $KnowledgeBase)
        Get-McpDocument -KnowledgeBase $KnowledgeBase -IncludeContent | Sort-Object -Property Id |
            Select-Object -Property Id, Title, Format, Tags, SourceType, Content | ConvertTo-Json -Depth 5
    }
}

AfterAll {
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Creating and listing knowledge bases' {
    It 'creates a knowledge base in PSMCPKB_HOME' {
        $kb = New-McpKnowledgeBase -Name Handbook -Description 'Operations handbook'
        $kb.Name | Should -Be 'Handbook'
        $kb.Description | Should -Be 'Operations handbook'
        $kb.Documents | Should -Be 0
        $kb.Path | Should -Be (Join-Path -Path $env:PSMCPKB_HOME -ChildPath 'knowledgebases' | Join-Path -ChildPath 'Handbook')
        Test-Path -LiteralPath (Join-Path $kb.Path 'knowledgebase.json') | Should -BeTrue
        { New-McpKnowledgeBase -Name Handbook } | Should -Throw '*already exists*'
    }

    It 'creates a knowledge base at a custom path and resolves it by path' {
        $folder = Join-Path -Path $script:Work -ChildPath 'project-kb'
        $kb = New-McpKnowledgeBase -Name Project -Description 'Kept next to the project' -Path $folder
        $kb.Path | Should -Be $folder
        (Get-McpKnowledgeBase -Name $folder).Name | Should -Be 'Project'
        Add-McpDocument -KnowledgeBase $folder -Title 'Build' -Content 'Run ./build.ps1 to build the project.' | Out-Null
        (Search-McpDocument -KnowledgeBase $folder -Query 'build project').Title | Should -Contain 'Build'
    }

    It 'lists all knowledge bases and filters them with wildcards' {
        New-McpKnowledgeBase -Name Hardware | Out-Null
        New-McpKnowledgeBase -Name Software | Out-Null
        (Get-McpKnowledgeBase).Name | Should -Be @('Handbook', 'Hardware', 'Software')
        (Get-McpKnowledgeBase -Name 'Ha*').Name | Should -Be @('Handbook', 'Hardware')
        Get-McpKnowledgeBase -Name 'Missing' -ErrorAction SilentlyContinue -ErrorVariable missing | Should -BeNullOrEmpty
        $missing | Should -Not -BeNullOrEmpty
    }

    It 'reports documents, tags and revision of a knowledge base' {
        Add-McpDocument -KnowledgeBase Handbook -Title 'Backup' -Content "# Backup`n`nThe nightly backup runs at 02:00 with Veeam." -Tags ops, backup | Out-Null
        Add-McpDocument -KnowledgeBase Handbook -Title 'Printer' -Content "# Printer`n`nThe hallway printer PRN-01 uses IPP." -Tags hardware | Out-Null
        $kb = Get-McpKnowledgeBase -Name Handbook
        $kb.Documents | Should -Be 2
        $kb.Tags | Should -Be @('backup', 'hardware', 'ops')
        $kb.Revision | Should -BeGreaterThan 0
        $kb.Characters | Should -BeGreaterThan 0
    }
}

Describe 'Updating knowledge bases' {
    It 'changes the description and returns the knowledge base with -PassThru' {
        Set-McpKnowledgeBase -Name Hardware -Description 'Printers and laptops' | Should -BeNullOrEmpty
        (Get-McpKnowledgeBase -Name Hardware).Description | Should -Be 'Printers and laptops'
        $updated = Set-McpKnowledgeBase -Name Hardware -Description 'Printers, laptops and phones' -PassThru
        $updated.Description | Should -Be 'Printers, laptops and phones'
    }
}

Describe 'Exporting and importing knowledge bases' {
    BeforeAll {
        $script:Snapshot = Get-DocumentSnapshot -KnowledgeBase Handbook
        $script:TopResult = (Search-McpDocument -KnowledgeBase Handbook -Query 'nightly backup' -Top 1).DocumentId
    }

    It 'exports a knowledge base to a ZIP archive' {
        $file = Export-McpKnowledgeBase -Name Handbook -DestinationPath $script:Archive
        $file.Name | Should -Be 'handbook.zip'
        Test-Path -LiteralPath $script:Archive | Should -BeTrue
        $file.Length | Should -BeGreaterThan 0
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($script:Archive)
        try { $entries = @($zip.Entries.FullName) } finally { $zip.Dispose() }
        $entries | Should -Contain 'knowledgebase.json'
        $entries | Should -Contain 'manifest.json'
        @($entries | Where-Object { $_ -like 'documents/*' }).Count | Should -Be 2
        @($entries | Where-Object { $_ -like 'index/*' }).Count | Should -Be 2
    }

    It 'overwrites an existing archive only with -Force' {
        { Export-McpKnowledgeBase -Name Handbook -DestinationPath $script:Archive } | Should -Throw '*-Force*'
        (Export-McpKnowledgeBase -Name Handbook -DestinationPath $script:Archive -Force).Length | Should -BeGreaterThan 0
    }

    It 'restores a removed knowledge base from the archive without changes' {
        Remove-McpKnowledgeBase -Name Handbook -Confirm:$false
        Get-McpKnowledgeBase -Name Handbook -ErrorAction SilentlyContinue | Should -BeNullOrEmpty

        $imported = Import-McpKnowledgeBase -Path $script:Archive
        $imported.Name | Should -Be 'Handbook'
        $imported.Description | Should -Be 'Operations handbook'
        Get-DocumentSnapshot -KnowledgeBase Handbook | Should -Be $script:Snapshot
        (Search-McpDocument -KnowledgeBase Handbook -Query 'nightly backup' -Top 1).DocumentId | Should -Be $script:TopResult
    }

    It 'imports under another name and replaces an existing knowledge base only with -Force' {
        (Import-McpKnowledgeBase -Path $script:Archive -Name HandbookCopy).Name | Should -Be 'HandbookCopy'
        { Import-McpKnowledgeBase -Path $script:Archive -Name HandbookCopy } | Should -Throw '*-Force*'

        Add-McpDocument -KnowledgeBase HandbookCopy -Title 'Draft' -Content 'A draft that the import replaces.' | Out-Null
        (Get-McpKnowledgeBase -Name HandbookCopy).Documents | Should -Be 3
        Import-McpKnowledgeBase -Path $script:Archive -Name HandbookCopy -Force -Confirm:$false | Out-Null
        (Get-McpKnowledgeBase -Name HandbookCopy).Documents | Should -Be 2
        Get-DocumentSnapshot -KnowledgeBase HandbookCopy | Should -Be $script:Snapshot
    }

    It 'keeps file sources updatable only with -TrustSource' {
        $source = Join-Path -Path $script:Work -ChildPath 'runbook.md'
        Set-Content -Path $source -Value "# Runbook`n`nRestart the service with systemctl."
        New-McpKnowledgeBase -Name Runbooks | Out-Null
        $doc = Add-McpDocument -KnowledgeBase Runbooks -Path $source
        $archive = Join-Path -Path $script:Work -ChildPath 'archives/runbooks.zip'
        Export-McpKnowledgeBase -Name Runbooks -DestinationPath $archive | Out-Null
        Set-Content -Path $source -Value "# Runbook`n`nRestart the service with the new script."

        # Untrusted (default): the content is imported, but the source file is never read again.
        Import-McpKnowledgeBase -Path $archive -Name RunbooksCopy -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null
        "$warnings" | Should -BeLike '*1 document(s)*'
        (Get-McpDocument -KnowledgeBase RunbooksCopy -Id $doc.Id).SourceType | Should -Be 'Imported'
        Update-McpDocument -KnowledgeBase RunbooksCopy -All | Should -BeNullOrEmpty
        (Get-McpDocument -KnowledgeBase RunbooksCopy -Id $doc.Id -IncludeContent).Content | Should -Match 'systemctl'

        # Trusted backup: the source stays a file and is updated from disk.
        Import-McpKnowledgeBase -Path $archive -Name RunbooksCopy -Force -TrustSource -Confirm:$false | Out-Null
        (Get-McpDocument -KnowledgeBase RunbooksCopy -Id $doc.Id).SourceType | Should -Be 'File'
        (Update-McpDocument -KnowledgeBase RunbooksCopy -All).Id | Should -Be $doc.Id
        (Get-McpDocument -KnowledgeBase RunbooksCopy -Id $doc.Id -IncludeContent).Content | Should -Match 'new script'
    }
}

Describe 'Removing knowledge bases' {
    It 'deletes the knowledge base folder with all documents' {
        $path = (Get-McpKnowledgeBase -Name Software).Path
        Remove-McpKnowledgeBase -Name Software -Confirm:$false
        Test-Path -LiteralPath $path | Should -BeFalse
        (Get-McpKnowledgeBase).Name | Should -Not -Contain 'Software'
    }
}
