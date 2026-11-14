BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
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
        { Import-McpKnowledgeBase -Path $bogus -Name Bogus } | Should -Throw '*not an MCPPosh knowledge base*'
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

    It 'rejects archives whose content exceeds the size limit' {
        $zip = New-TestArchive -Name 'Big' -Files @{ 'documents/big-1a2b3c.md' = ('x' * 5000) }
        InModuleScope MCPPosh { $script:McpMaxArchiveBytes = 1000 }
        try {
            { Import-McpKnowledgeBase -Path $zip } | Should -Throw '*exceeds the limit*'
        }
        finally {
            InModuleScope MCPPosh { $script:McpMaxArchiveBytes = 1GB }
        }
        Get-McpKnowledgeBase -Name 'Big' -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'rejects archives with too many entries' {
        $zip = New-TestArchive -Name 'Many' -Files @{ 'documents/one-1a2b3c.md' = 'one'; 'documents/two-1a2b3c.md' = 'two' }
        InModuleScope MCPPosh { $script:McpMaxArchiveEntries = 3 }
        try {
            { Import-McpKnowledgeBase -Path $zip } | Should -Throw '*more than 3 entries*'
        }
        finally {
            InModuleScope MCPPosh { $script:McpMaxArchiveEntries = 100000 }
        }
    }
}
