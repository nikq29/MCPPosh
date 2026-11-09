BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:TestHome = Initialize-McpTestEnvironment -Name transfer
    New-McpKnowledgeBase -Name Source -Description 'Quelle' | Out-Null
    Add-McpDocument -KnowledgeBase Source -Title 'Eins' -Content "# Eins`n`nErster Inhalt über Zertifikate." | Out-Null
    Add-McpDocument -KnowledgeBase Source -Title 'Zwei' -Content "# Zwei`n`nZweiter Inhalt." | Out-Null

    # Stubs with the relevant parameters so the Az.Storage cmdlets can be mocked without the Az modules.
    $script:AzStubs = @{
        'New-AzStorageContext'     = { param($StorageAccountName, $StorageAccountKey, $SasToken) }
        'Get-AzStorageAccountKey'  = { param($ResourceGroupName, $Name) }
        'Get-AzStorageFile'        = { param($ShareName, $Path, $Context, [Parameter(ValueFromPipeline)] $Directory) process { } }
        'New-AzStorageDirectory'   = { param($ShareName, $Path, $Context) }
        'Set-AzStorageFileContent' = { param($ShareName, $Source, $Path, $Context, [switch] $Force) }
        'Remove-AzStorageFile'     = { param($ShareName, $Path, $Context) }
    }
    foreach ($stub in $script:AzStubs.GetEnumerator()) {
        if (-not (Get-Command $stub.Key -ErrorAction SilentlyContinue)) {
            Set-Item -Path "function:global:$($stub.Key)" -Value $stub.Value
        }
    }
}

AfterAll {
    foreach ($name in 'New-AzStorageContext', 'Get-AzStorageAccountKey', 'Get-AzStorageFile', 'New-AzStorageDirectory', 'Set-AzStorageFileContent', 'Remove-AzStorageFile') {
        Remove-Item -Path "function:global:$name" -ErrorAction SilentlyContinue
    }
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Export and import' {
    It 'round-trips a knowledge base through a ZIP archive' {
        $zip = Join-Path $script:TestHome 'source.zip'
        $file = Export-McpKnowledgeBase -Name Source -DestinationPath $zip
        $file.Length | Should -BeGreaterThan 0

        $entries = InModuleScope MCPPosh -Parameters @{ Zip = $zip } {
            param($Zip)
            $archive = [System.IO.Compression.ZipFile]::OpenRead($Zip)
            try { $archive.Entries.FullName } finally { $archive.Dispose() }
        }
        $entries | Should -Contain 'manifest.json'
        $entries | Should -Contain 'knowledgebase.json'
        ($entries | Where-Object { $_ -like 'documents/*' }).Count | Should -Be 2
        $entries | Where-Object { $_ -like 'logs/*' -or $_ -like '*.lock' } | Should -BeNullOrEmpty

        $imported = Import-McpKnowledgeBase -Path $zip -Name Copy
        $imported.Name | Should -Be 'Copy'
        $imported.Documents | Should -Be 2
        $imported.Description | Should -Be 'Quelle'
        (Search-McpDocument -KnowledgeBase Copy -Query 'Zertifikate')[0].Title | Should -Be 'Eins'
    }

    It 'refuses to overwrite without -Force' {
        $zip = Join-Path $script:TestHome 'source2.zip'
        Export-McpKnowledgeBase -Name Source -DestinationPath $zip | Out-Null
        { Export-McpKnowledgeBase -Name Source -DestinationPath $zip } | Should -Throw '*already exists*'
        { Import-McpKnowledgeBase -Path $zip } | Should -Throw '*already exists*'
        Add-McpDocument -KnowledgeBase Source -Title 'Drei' -Content 'drei' | Out-Null
        Export-McpKnowledgeBase -Name Source -DestinationPath $zip -Force | Out-Null
        (Import-McpKnowledgeBase -Path $zip -Name Copy -Force -Confirm:$false).Documents | Should -Be 3
    }

    It 'rejects archives that are not knowledge bases' {
        $bogus = Join-Path $script:TestHome 'bogus.zip'
        $folder = Join-Path $script:TestHome 'bogus'
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        Set-Content -Path (Join-Path $folder 'readme.txt') -Value 'hi'
        Compress-Archive -Path (Join-Path $folder '*') -DestinationPath $bogus
        { Import-McpKnowledgeBase -Path $bogus -Name Bogus } | Should -Throw '*not an MCPPosh knowledge base*'
        Get-McpKnowledgeBase -Name Bogus -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }
}

Describe 'Publish-McpKnowledgeBase' {
    BeforeEach {
        $script:Uploads = [System.Collections.Generic.List[string]]::new()
        $script:Deletes = [System.Collections.Generic.List[string]]::new()
        $script:Directories = [System.Collections.Generic.List[string]]::new()
    }

    It 'uploads changed files with the manifest last and skips unchanged files' {
        InModuleScope MCPPosh -Parameters @{ Uploads = $script:Uploads; Directories = $script:Directories } {
            param($Uploads, $Directories)
            Mock Assert-McpAzStorageModule { }
            Mock New-AzStorageContext { [pscustomobject]@{ StorageAccountName = 'acct' } }
            Mock Get-AzStorageFile { $null }
            Mock New-AzStorageDirectory { $Directories.Add($Path) }
            Mock Set-AzStorageFileContent { $Uploads.Add($Path) }

            $first = Publish-McpKnowledgeBase -Name Source -StorageAccountName acct -StorageAccountKey 'a2V5' -ShareName mcpposh
            $first.Uploaded | Should -Be $Uploads.Count
            $Uploads[-1] | Should -Be 'knowledgebases/Source/manifest.json'
            $Uploads | Should -Contain 'knowledgebases/Source/knowledgebase.json'
            ($Uploads | Where-Object { $_ -like 'knowledgebases/Source/documents/*.md' }).Count | Should -Be 3
            ($Uploads | Where-Object { $_ -like 'knowledgebases/Source/index/*.json' }).Count | Should -Be 3
            $Directories | Should -Be @('knowledgebases', 'knowledgebases/Source', 'knowledgebases/Source/documents', 'knowledgebases/Source/index')
            $first.Destination | Should -Be 'https://acct.file.core.windows.net/mcpposh/knowledgebases/Source'

            $Uploads.Clear()
            $second = Publish-McpKnowledgeBase -Name Source -StorageAccountName acct -StorageAccountKey 'a2V5' -ShareName mcpposh
            $second.Uploaded | Should -Be 1 -Because 'only the manifest is always uploaded'
            $Uploads | Should -Be @('knowledgebases/Source/manifest.json')

            Add-McpDocument -KnowledgeBase Source -Title 'Vier' -Content 'vier' | Out-Null
            $Uploads.Clear()
            $third = Publish-McpKnowledgeBase -Name Source -StorageAccountName acct -StorageAccountKey 'a2V5' -ShareName mcpposh
            $third.Uploaded | Should -Be 3 -Because 'one new document, its index and the manifest changed'
        }
    }

    It 'prunes remote documents that were removed locally' {
        InModuleScope MCPPosh -Parameters @{ Deletes = $script:Deletes } {
            param($Deletes)
            Mock Assert-McpAzStorageModule { }
            Mock New-AzStorageContext { [pscustomobject]@{ StorageAccountName = 'acct' } }
            Mock New-AzStorageDirectory { }
            Mock Set-AzStorageFileContent { }
            Mock Get-AzStorageFile { [pscustomobject]@{ Name = 'directory' } } -ParameterFilter { $Path }
            Mock Get-AzStorageFile { [pscustomobject]@{ Name = 'obsolete-123456.md' }; [pscustomobject]@{ Name = 'obsolete-123456.json' } } -ParameterFilter { -not $Path }
            Mock Remove-AzStorageFile { $Deletes.Add($Path) }

            $result = Publish-McpKnowledgeBase -Name Source -StorageAccountName acct -StorageAccountKey 'a2V5' -ShareName mcpposh -Prune -RemoteName Docs
            $result.Deleted | Should -BeGreaterThan 0
            $Deletes | Should -Contain 'knowledgebases/Docs/documents/obsolete-123456.md'
            $Deletes | Should -Contain 'knowledgebases/Docs/index/obsolete-123456.json'
        }
    }

    It 'reads the storage key from the resource group when requested' {
        InModuleScope MCPPosh {
            Mock Assert-McpAzStorageModule { }
            Mock Get-AzStorageAccountKey { @([pscustomobject]@{ KeyName = 'key1'; Value = 'c2VjcmV0' }) }
            Mock New-AzStorageContext { [pscustomobject]@{ StorageAccountName = $StorageAccountName } } -ParameterFilter { $StorageAccountKey -eq 'c2VjcmV0' }
            Mock Get-AzStorageFile { $null }
            Mock New-AzStorageDirectory { }
            Mock Set-AzStorageFileContent { }
            Publish-McpKnowledgeBase -Name Source -StorageAccountName acct -ResourceGroupName rg -ShareName mcpposh -Force | Out-Null
            Should -Invoke Get-AzStorageAccountKey -Times 1 -ParameterFilter { $ResourceGroupName -eq 'rg' -and $Name -eq 'acct' }
            Should -Invoke New-AzStorageContext -Times 1
        }
    }

    It 'explains how to install Az.Storage when it is missing' {
        InModuleScope MCPPosh {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'Set-AzStorageFileContent' }
            Mock Get-Module { $null } -ParameterFilter { $Name -eq 'Az.Storage' }
            { Assert-McpAzStorageModule } | Should -Throw '*Install-Module Az.Storage*'
        }
    }
}
