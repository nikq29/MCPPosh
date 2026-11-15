BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/PSMcpKnowledgeBase.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'PSMcpKnowledgeBase'
    Register-McpTestAzStub
    New-McpKnowledgeBase -Name Source | Out-Null
    Add-McpDocument -KnowledgeBase Source -Title 'One' -Content '# One' | Out-Null
    Add-McpDocument -KnowledgeBase Source -Title 'Two' -Content '# Two' | Out-Null
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Unregister-McpTestAzStub
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Publish-McpKnowledgeBase' {
    It 'uploads changed files with the manifest last and skips unchanged files' {
        InModuleScope PSMcpKnowledgeBase {
            $uploads = [System.Collections.Generic.List[string]]::new()
            $directories = [System.Collections.Generic.List[string]]::new()
            Mock Assert-McpAzStorageModule { }
            Mock New-AzStorageContext { [pscustomobject]@{ StorageAccountName = 'acct' } }
            Mock Get-AzStorageFile { $null }
            Mock New-AzStorageDirectory { $directories.Add($Path) }
            Mock Set-AzStorageFileContent { $uploads.Add($Path) }

            $first = Publish-McpKnowledgeBase -Name Source -StorageAccountName acct -StorageAccountKey 'a2V5' -ShareName psmcpkb
            $first.Uploaded | Should -Be $uploads.Count
            $uploads[-1] | Should -Be 'knowledgebases/Source/manifest.json'
            @($uploads | Where-Object { $_ -like 'knowledgebases/Source/documents/*.md' }).Count | Should -Be 2
            $directories | Should -Be @('knowledgebases', 'knowledgebases/Source', 'knowledgebases/Source/documents', 'knowledgebases/Source/index')
            $first.Destination | Should -Be 'https://acct.file.core.windows.net/psmcpkb/knowledgebases/Source'

            $uploads.Clear()
            (Publish-McpKnowledgeBase -Name Source -StorageAccountName acct -StorageAccountKey 'a2V5' -ShareName psmcpkb).Uploaded | Should -Be 1
            $uploads | Should -Be @('knowledgebases/Source/manifest.json')
        }
    }

    It 'prunes remote documents that no longer exist locally' {
        InModuleScope PSMcpKnowledgeBase {
            $deletes = [System.Collections.Generic.List[string]]::new()
            Mock Assert-McpAzStorageModule { }
            Mock New-AzStorageContext { [pscustomobject]@{ StorageAccountName = 'acct' } }
            Mock New-AzStorageDirectory { }
            Mock Set-AzStorageFileContent { }
            Mock Get-AzStorageFile { [pscustomobject]@{ Name = 'directory' } } -ParameterFilter { $Path }
            Mock Get-AzStorageFile { [pscustomobject]@{ Name = 'obsolete-123456.md' }; [pscustomobject]@{ Name = 'obsolete-123456.json' } } -ParameterFilter { -not $Path }
            Mock Remove-AzStorageFile { $deletes.Add($Path) }

            $result = Publish-McpKnowledgeBase -Name Source -StorageAccountName acct -StorageAccountKey 'a2V5' -ShareName psmcpkb -Prune -RemoteName Docs
            $result.Deleted | Should -BeGreaterThan 0
            $deletes | Should -Contain 'knowledgebases/Docs/documents/obsolete-123456.md'
        }
    }

    It 'stops when the share holds documents that were neither published from here nor exist locally' {
        InModuleScope PSMcpKnowledgeBase {
            Mock Assert-McpAzStorageModule { }
            Mock New-AzStorageContext { [pscustomobject]@{ StorageAccountName = 'acct' } }
            Mock Get-AzStorageFile { $null }
            Mock New-AzStorageDirectory { }
            Mock Set-AzStorageFileContent { }
            Mock Get-AzStorageFileContent { Set-Content -LiteralPath $Destination -Value '{"documents":[{"id":"finding-abc123","title":"Agent finding","sourceType":"Agent"}]}' }

            { Publish-McpKnowledgeBase -Name Source -StorageAccountName acct -StorageAccountKey 'a2V5' -ShareName psmcpkb -RemoteName Notes } | Should -Throw "*'Agent finding' (finding-abc123)*"
            Should -Invoke Set-AzStorageFileContent -Times 0
            (Publish-McpKnowledgeBase -Name Source -StorageAccountName acct -StorageAccountKey 'a2V5' -ShareName psmcpkb -RemoteName Notes -Force).Uploaded | Should -BeGreaterThan 0
        }
    }

    It 'checks again before the manifest upload, so a note saved during the upload is not dropped' {
        InModuleScope PSMcpKnowledgeBase {
            $downloads = [System.Collections.Generic.List[int]]::new()
            $uploads = [System.Collections.Generic.List[string]]::new()
            Mock Assert-McpAzStorageModule { }
            Mock New-AzStorageContext { [pscustomobject]@{ StorageAccountName = 'acct' } }
            Mock Get-AzStorageFile { $null }
            Mock New-AzStorageDirectory { }
            Mock Set-AzStorageFileContent { $uploads.Add($Path) }
            # The first download sees no agent notes; an agent saves one while the documents are uploaded.
            Mock Get-AzStorageFileContent {
                $downloads.Add(1)
                if ($downloads.Count -ge 2) { Set-Content -LiteralPath $Destination -Value '{"documents":[{"id":"late-abc123","title":"Late note","sourceType":"Agent"}]}' }
            }

            { Publish-McpKnowledgeBase -Name Source -StorageAccountName acct -StorageAccountKey 'a2V5' -ShareName psmcpkb -RemoteName Race } | Should -Throw "*'Late note' (late-abc123)*"
            $downloads.Count | Should -Be 2
            $uploads | Should -Not -Contain 'knowledgebases/Race/manifest.json'
            @($uploads | Where-Object { $_ -like 'knowledgebases/Race/documents/*' }).Count | Should -BeGreaterThan 0
        }
    }

    It 'reads the storage account key from the resource group' {
        InModuleScope PSMcpKnowledgeBase {
            Mock Assert-McpAzStorageModule { }
            Mock Get-AzStorageAccountKey { @([pscustomobject]@{ KeyName = 'key1'; Value = 'c2VjcmV0' }) }
            Mock New-AzStorageContext { [pscustomobject]@{ StorageAccountName = $StorageAccountName } } -ParameterFilter { $StorageAccountKey -eq 'c2VjcmV0' }
            Mock Get-AzStorageFile { $null }
            Mock New-AzStorageDirectory { }
            Mock Set-AzStorageFileContent { }
            Publish-McpKnowledgeBase -Name Source -StorageAccountName acct -ResourceGroupName rg -ShareName psmcpkb -Force | Out-Null
            Should -Invoke Get-AzStorageAccountKey -Times 1 -ParameterFilter { $ResourceGroupName -eq 'rg' -and $Name -eq 'acct' }
        }
    }

    It 'accepts an existing storage context' {
        InModuleScope PSMcpKnowledgeBase {
            Mock Assert-McpAzStorageModule { }
            Mock Get-AzStorageFile { $null }
            Mock New-AzStorageDirectory { }
            Mock Set-AzStorageFileContent { }
            $result = Publish-McpKnowledgeBase -Name Source -Context ([pscustomobject]@{ StorageAccountName = 'ctxacct' }) -ShareName psmcpkb -Force
            $result.Destination | Should -Match 'ctxacct'
        }
    }
}
