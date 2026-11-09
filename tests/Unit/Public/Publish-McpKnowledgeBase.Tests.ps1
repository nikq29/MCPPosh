BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
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
        InModuleScope MCPPosh {
            $uploads = [System.Collections.Generic.List[string]]::new()
            $directories = [System.Collections.Generic.List[string]]::new()
            Mock Assert-McpAzStorageModule { }
            Mock New-AzStorageContext { [pscustomobject]@{ StorageAccountName = 'acct' } }
            Mock Get-AzStorageFile { $null }
            Mock New-AzStorageDirectory { $directories.Add($Path) }
            Mock Set-AzStorageFileContent { $uploads.Add($Path) }

            $first = Publish-McpKnowledgeBase -Name Source -StorageAccountName acct -StorageAccountKey 'a2V5' -ShareName mcpposh
            $first.Uploaded | Should -Be $uploads.Count
            $uploads[-1] | Should -Be 'knowledgebases/Source/manifest.json'
            @($uploads | Where-Object { $_ -like 'knowledgebases/Source/documents/*.md' }).Count | Should -Be 2
            $directories | Should -Be @('knowledgebases', 'knowledgebases/Source', 'knowledgebases/Source/documents', 'knowledgebases/Source/index')
            $first.Destination | Should -Be 'https://acct.file.core.windows.net/mcpposh/knowledgebases/Source'

            $uploads.Clear()
            (Publish-McpKnowledgeBase -Name Source -StorageAccountName acct -StorageAccountKey 'a2V5' -ShareName mcpposh).Uploaded | Should -Be 1
            $uploads | Should -Be @('knowledgebases/Source/manifest.json')
        }
    }

    It 'prunes remote documents that no longer exist locally' {
        InModuleScope MCPPosh {
            $deletes = [System.Collections.Generic.List[string]]::new()
            Mock Assert-McpAzStorageModule { }
            Mock New-AzStorageContext { [pscustomobject]@{ StorageAccountName = 'acct' } }
            Mock New-AzStorageDirectory { }
            Mock Set-AzStorageFileContent { }
            Mock Get-AzStorageFile { [pscustomobject]@{ Name = 'directory' } } -ParameterFilter { $Path }
            Mock Get-AzStorageFile { [pscustomobject]@{ Name = 'obsolete-123456.md' }; [pscustomobject]@{ Name = 'obsolete-123456.json' } } -ParameterFilter { -not $Path }
            Mock Remove-AzStorageFile { $deletes.Add($Path) }

            $result = Publish-McpKnowledgeBase -Name Source -StorageAccountName acct -StorageAccountKey 'a2V5' -ShareName mcpposh -Prune -RemoteName Docs
            $result.Deleted | Should -BeGreaterThan 0
            $deletes | Should -Contain 'knowledgebases/Docs/documents/obsolete-123456.md'
        }
    }

    It 'reads the storage account key from the resource group' {
        InModuleScope MCPPosh {
            Mock Assert-McpAzStorageModule { }
            Mock Get-AzStorageAccountKey { @([pscustomobject]@{ KeyName = 'key1'; Value = 'c2VjcmV0' }) }
            Mock New-AzStorageContext { [pscustomobject]@{ StorageAccountName = $StorageAccountName } } -ParameterFilter { $StorageAccountKey -eq 'c2VjcmV0' }
            Mock Get-AzStorageFile { $null }
            Mock New-AzStorageDirectory { }
            Mock Set-AzStorageFileContent { }
            Publish-McpKnowledgeBase -Name Source -StorageAccountName acct -ResourceGroupName rg -ShareName mcpposh -Force | Out-Null
            Should -Invoke Get-AzStorageAccountKey -Times 1 -ParameterFilter { $ResourceGroupName -eq 'rg' -and $Name -eq 'acct' }
        }
    }

    It 'accepts an existing storage context' {
        InModuleScope MCPPosh {
            Mock Assert-McpAzStorageModule { }
            Mock Get-AzStorageFile { $null }
            Mock New-AzStorageDirectory { }
            Mock Set-AzStorageFileContent { }
            $result = Publish-McpKnowledgeBase -Name Source -Context ([pscustomobject]@{ StorageAccountName = 'ctxacct' }) -ShareName mcpposh -Force
            $result.Destination | Should -Match 'ctxacct'
        }
    }
}
