BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/PSMcpKnowledgeBase.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'PSMcpKnowledgeBase'
    New-McpKnowledgeBase -Name Source -Description 'Source' | Out-Null
    Add-McpDocument -KnowledgeBase Source -Title 'One' -Content "# One`n`nFirst content about certificates." | Out-Null
    $script:Zip = Join-Path $script:TestHome 'source.zip'
    Export-McpKnowledgeBase -Name Source -DestinationPath $script:Zip | Out-Null
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Import-McpKnowledgeBase' {
    It 'imports an archive under a new name' {
        $kb = Import-McpKnowledgeBase -Path $script:Zip -Name Copy
        $kb.Name | Should -Be 'Copy'
        $kb.Documents | Should -Be 1
        $kb.Description | Should -Be 'Source'
        (Search-McpDocument -KnowledgeBase Copy -Query 'certificates')[0].Title | Should -Be 'One'
    }

    It 'refuses to replace an existing knowledge base without -Force' {
        { Import-McpKnowledgeBase -Path $script:Zip } | Should -Throw '*already exists*'
        (Import-McpKnowledgeBase -Path $script:Zip -Name Copy -Force -Confirm:$false).Name | Should -Be 'Copy'
    }

    It 'rejects archives that are not knowledge bases' {
        $folder = Join-Path $script:TestHome 'bogus'
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        Set-Content -Path (Join-Path $folder 'readme.txt') -Value 'hi'
        $bogus = Join-Path $script:TestHome 'bogus.zip'
        Compress-Archive -Path (Join-Path $folder '*') -DestinationPath $bogus
        { Import-McpKnowledgeBase -Path $bogus -Name Bogus } | Should -Throw '*not an PSMcpKnowledgeBase knowledge base*'
        Get-McpKnowledgeBase -Name Bogus -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'fails for missing archives' {
        { Import-McpKnowledgeBase -Path (Join-Path $script:TestHome 'missing.zip') } | Should -Throw '*was not found*'
    }
}

Describe 'Import-McpKnowledgeBase (untrusted archives)' {
    BeforeAll {
        function New-TestArchive {
            param([string] $Name, [object[]] $Documents = @(), [hashtable] $Files = @{})
            $folder = Join-Path $script:TestHome "archive-$Name"
            New-Item -ItemType Directory -Path (Join-Path $folder 'documents') -Force | Out-Null
            Set-Content -Path (Join-Path $folder 'knowledgebase.json') -Value (@{ schemaVersion = 1; name = $Name; description = '' } | ConvertTo-Json)
            Set-Content -Path (Join-Path $folder 'manifest.json') -Value (@{ schemaVersion = 1; revision = 1; documents = $Documents } | ConvertTo-Json -Depth 5)
            foreach ($file in $Files.GetEnumerator()) { Set-Content -Path (Join-Path $folder $file.Key) -Value $file.Value }
            $zip = "$folder.zip"
            [System.IO.Compression.ZipFile]::CreateFromDirectory($folder, $zip)
            $zip
        }
    }

    It 'rejects the document id <BadId> that points outside the knowledge base' -ForEach @(
        @{ Name = 'EvilRelative'; BadId = '../../../outside/secret' }
        @{ Name = 'EvilAbsolute'; BadId = '/etc/secret' }
    ) {
        $zip = New-TestArchive -Name $Name -Documents @(@{ id = $BadId; title = 'innocent'; format = 'Markdown'; sourceType = 'Inline'; tags = @() })
        { Import-McpKnowledgeBase -Path $zip } | Should -Throw '*invalid document id*'
        Get-McpKnowledgeBase -Name $Name -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    Context 'documents with sources chosen by the archive author' {
        BeforeAll {
            # Stands in for a file of the importing user, for example ~/.ssh/id_rsa or ~/.aws/credentials.
            $script:Secret = Join-Path $script:TestHome 'victim-secret.txt'
            Set-Content -Path $script:Secret -Value 'CANARY-SECRET do not leak'
            function New-SourceArchive {
                param([string] $Name, [object] $SourceType = 'File')
                New-TestArchive -Name $Name -Documents @(
                    @{ id = 'onboarding-1a2b3c'; title = 'Onboarding'; format = 'Text'; sourceType = $SourceType; source = $script:Secret; sourceHash = 'x'; tags = @() }
                    @{ id = 'portal-1a2b3c'; title = 'Portal'; format = 'Html'; sourceType = 'Url'; source = 'http://127.0.0.1:9/internal'; tags = @() }
                    @{ id = 'welcome-1a2b3c'; title = 'Welcome'; format = 'Markdown'; sourceType = 'Inline'; tags = @() }
                ) -Files @{
                    'documents/onboarding-1a2b3c.md' = 'Harmless onboarding text.'
                    'documents/portal-1a2b3c.md'     = 'Harmless portal text.'
                    'documents/welcome-1a2b3c.md'    = '# Welcome'
                }
            }
        }

        It 'imports File and Url documents as Imported documents that keep their content' {
            $zip = New-SourceArchive -Name 'Sources'
            Import-McpKnowledgeBase -Path $zip -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null
            $warnings | Should -HaveCount 1
            "$warnings" | Should -BeLike '*2 document(s)*-TrustSource*'

            $docs = @(Get-McpDocument -KnowledgeBase Sources -IncludeContent)
            ($docs | Where-Object Id -EQ 'onboarding-1a2b3c').SourceType | Should -Be 'Imported'
            ($docs | Where-Object Id -EQ 'portal-1a2b3c').SourceType | Should -Be 'Imported'
            ($docs | Where-Object Id -EQ 'welcome-1a2b3c').SourceType | Should -Be 'Inline'
            ($docs | Where-Object Id -EQ 'onboarding-1a2b3c').Content | Should -Match 'Harmless onboarding'
            @(Get-McpDocument -KnowledgeBase Sources -SourceType Imported).Count | Should -Be 2

            $manifest = Get-Content -Raw (Join-Path (Get-McpKnowledgeBase -Name Sources).Path 'manifest.json') | ConvertFrom-Json -AsHashtable
            @($manifest.documents | Where-Object { $_.Contains('sourceHash') }) | Should -BeNullOrEmpty
        }

        It 'never lets Update-McpDocument read the sources of an untrusted archive' {
            Update-McpDocument -KnowledgeBase Sources -All -Force -Confirm:$false | Should -BeNullOrEmpty
            $content = (Get-McpDocument -KnowledgeBase Sources -Id onboarding-1a2b3c -IncludeContent).Content
            $content | Should -Not -Match 'CANARY-SECRET'
            $content | Should -Match 'Harmless onboarding'
            (Search-McpDocument -KnowledgeBase Sources -Query 'CANARY') | Should -BeNullOrEmpty
        }

        It 'keeps Imported documents editable with Set-McpDocument' {
            Set-McpDocument -KnowledgeBase Sources -Id onboarding-1a2b3c -AddTags reviewed
            $doc = Get-McpDocument -KnowledgeBase Sources -Id onboarding-1a2b3c
            $doc.Tags | Should -Contain 'reviewed'
            $doc.SourceType | Should -Be 'Imported'
        }

        It 'converts the source type <Label> so it cannot reach the File branch of Update-McpDocument' -ForEach @(
            @{ Name = 'LowerCase'; Label = "'file'"; SourceType = 'file' }
            @{ Name = 'ArrayType'; Label = "@('Inline', 'File')"; SourceType = @('Inline', 'File') }
            @{ Name = 'UnknownType'; Label = "'Bogus'"; SourceType = 'Bogus' }
        ) {
            $zip = New-SourceArchive -Name $Name -SourceType $SourceType
            Import-McpKnowledgeBase -Path $zip -WarningAction SilentlyContinue | Out-Null
            (Get-McpDocument -KnowledgeBase $Name -Id onboarding-1a2b3c).SourceType | Should -Be 'Imported'
            Update-McpDocument -KnowledgeBase $Name -All -Force -Confirm:$false | Out-Null
            (Get-McpDocument -KnowledgeBase $Name -Id onboarding-1a2b3c -IncludeContent).Content | Should -Not -Match 'CANARY-SECRET'
        }

        It 'keeps the sources with -TrustSource' {
            $zip = New-SourceArchive -Name 'Trusted'
            Import-McpKnowledgeBase -Path $zip -TrustSource -WarningVariable warnings | Out-Null
            $warnings | Should -BeNullOrEmpty
            $doc = Get-McpDocument -KnowledgeBase Trusted -Id onboarding-1a2b3c
            $doc.SourceType | Should -Be 'File'
            $doc.Source | Should -Be $script:Secret
            # The archive is trusted, so its sources are read again.
            Update-McpDocument -KnowledgeBase Trusted -Id onboarding-1a2b3c -Confirm:$false | Out-Null
            (Get-McpDocument -KnowledgeBase Trusted -Id onboarding-1a2b3c -IncludeContent).Content | Should -Match 'CANARY-SECRET'
        }
    }

    It 'rejects archives whose content exceeds the size limit' {
        $zip = New-TestArchive -Name 'Big' -Files @{ 'documents/big-1a2b3c.md' = ('x' * 5000) }
        InModuleScope PSMcpKnowledgeBase { $script:McpMaxArchiveBytes = 1000 }
        try {
            { Import-McpKnowledgeBase -Path $zip } | Should -Throw '*exceeds the limit*'
        }
        finally {
            InModuleScope PSMcpKnowledgeBase { $script:McpMaxArchiveBytes = 1GB }
        }
        Get-McpKnowledgeBase -Name 'Big' -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'rejects archives with too many entries' {
        $zip = New-TestArchive -Name 'Many' -Files @{ 'documents/one-1a2b3c.md' = 'one'; 'documents/two-1a2b3c.md' = 'two' }
        InModuleScope PSMcpKnowledgeBase { $script:McpMaxArchiveEntries = 3 }
        try {
            { Import-McpKnowledgeBase -Path $zip } | Should -Throw '*more than 3 entries*'
        }
        finally {
            InModuleScope PSMcpKnowledgeBase { $script:McpMaxArchiveEntries = 100000 }
        }
    }
}
