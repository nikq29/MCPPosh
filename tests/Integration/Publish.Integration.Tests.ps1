<#
    End-to-end tests of Publish-McpKnowledgeBase. Azure Files is replaced by a local folder
    (Register-McpTestAzFileShare); everything else is real: the incremental upload, -Force, -Prune, and a server
    that serves the published knowledge base from the share like the hosted container does.
#>
BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment -Name publish
    $script:AzureRoot = Join-Path -Path $script:TestHome -ChildPath 'azure'
    Register-McpTestAzFileShare -Root $script:AzureRoot
    # The share exists before the first publish (the Bicep template creates it).
    New-Item -ItemType Directory -Path (Join-Path $script:AzureRoot 'mcpposhstore/mcpposh') -Force | Out-Null
    $script:Remote = Join-Path -Path $script:AzureRoot -ChildPath 'mcpposhstore/mcpposh/knowledgebases/Docs'

    New-McpKnowledgeBase -Name Contoso -Description 'Published documentation' | Out-Null
    $script:Backup = Add-McpDocument -KnowledgeBase Contoso -Title 'Backup' -Content "# Backup`n`nThe nightly backup runs at 02:00 with Veeam."
    $script:Printer = Add-McpDocument -KnowledgeBase Contoso -Title 'Printer' -Content "# Printer`n`nThe hallway printer is PRN-01."
    $script:LocalPath = (Get-McpKnowledgeBase -Name Contoso).Path

    function Get-TreeHash {
        param([string] $Path)
        $Path = (Get-Item -LiteralPath $Path).FullName.TrimEnd('\', '/')
        Get-ChildItem -LiteralPath $Path -Recurse -File |
            Where-Object { $_.FullName.Substring($Path.Length + 1).Replace('\', '/') -match '^(knowledgebase\.json|manifest\.json|documents/[^/]+|index/[^/]+)$' } |
            ForEach-Object { '{0} {1}' -f $_.FullName.Substring($Path.Length + 1).Replace('\', '/'), (Get-FileHash -LiteralPath $_.FullName).Hash } |
            Sort-Object
    }

    function Get-UploadLog {
        @($global:McpTestAzFileShareLog | Where-Object Action -EQ 'Upload' | ForEach-Object Path)
    }
}

AfterAll {
    Stop-McpServer -All -Confirm:$false -ErrorAction SilentlyContinue
    Unregister-McpTestAzStub
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Publishing a knowledge base to Azure Files' {
    It 'uploads all files with a storage account key and the manifest last' {
        $result = Publish-McpKnowledgeBase -Name Contoso -StorageAccountName mcpposhstore -ShareName mcpposh -StorageAccountKey 'account-key' -RemoteName Docs
        $result.PSObject.TypeNames | Should -Contain 'MCPPosh.PublishResult'
        $result.KnowledgeBase | Should -Be 'Contoso'
        $result.Destination | Should -Be 'https://mcpposhstore.file.core.windows.net/mcpposh/knowledgebases/Docs'
        $result.Uploaded | Should -Be 6
        $result.Skipped | Should -Be 0
        $result.Deleted | Should -Be 0
        Get-TreeHash -Path $script:Remote | Should -Be (Get-TreeHash -Path $script:LocalPath)
        (Get-UploadLog)[-1] | Should -Be 'knowledgebases/Docs/manifest.json'
    }

    It 'uploads only changed files with a SAS token' {
        $global:McpTestAzFileShareLog.Clear()
        $added = Add-McpDocument -KnowledgeBase Contoso -Title 'VPN' -Content "# VPN`n`nThe VPN gateway uses WireGuard."
        $result = Publish-McpKnowledgeBase -Name Contoso -StorageAccountName mcpposhstore -ShareName mcpposh -SasToken '?sv=2024-01-01&sig=fake' -RemoteName Docs
        $result.Uploaded | Should -Be 3
        $result.Skipped | Should -Be 5
        @(Get-UploadLog) | Should -Be @("knowledgebases/Docs/documents/$($added.Id).md", "knowledgebases/Docs/index/$($added.Id).json", 'knowledgebases/Docs/manifest.json')
        Get-TreeHash -Path $script:Remote | Should -Be (Get-TreeHash -Path $script:LocalPath)
    }

    It 'uploads all files again with -Force and reads the key from the resource group' {
        $global:McpTestAzFileShareLog.Clear()
        $result = Publish-McpKnowledgeBase -Name Contoso -StorageAccountName mcpposhstore -ShareName mcpposh -ResourceGroupName rg-mcpposh -RemoteName Docs -Force
        $result.Uploaded | Should -Be 8
        $result.Skipped | Should -Be 0
        @($global:McpTestAzFileShareLog | Where-Object Action -EQ 'GetKey').Path | Should -Be 'rg-mcpposh/mcpposhstore'
    }

    It 'deletes documents that were removed locally with -Prune and an existing storage context' {
        Remove-McpDocument -KnowledgeBase Contoso -Id $script:Printer.Id -Confirm:$false
        $context = New-AzStorageContext -StorageAccountName mcpposhstore -StorageAccountKey 'account-key'

        $kept = Publish-McpKnowledgeBase -Name Contoso -Context $context -ShareName mcpposh -RemoteName Docs
        $kept.Deleted | Should -Be 0
        Test-Path -LiteralPath (Join-Path $script:Remote "documents/$($script:Printer.Id).md") | Should -BeTrue

        $pruned = Publish-McpKnowledgeBase -Name Contoso -Context $context -ShareName mcpposh -RemoteName Docs -Prune
        $pruned.Deleted | Should -Be 2
        Test-Path -LiteralPath (Join-Path $script:Remote "documents/$($script:Printer.Id).md") | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $script:Remote "index/$($script:Printer.Id).json") | Should -BeFalse
        Get-TreeHash -Path $script:Remote | Should -Be (Get-TreeHash -Path $script:LocalPath)
    }

    It 'publishes under the local name when -RemoteName is omitted' {
        $result = Publish-McpKnowledgeBase -Name Contoso -StorageAccountName mcpposhstore -ShareName mcpposh -StorageAccountKey 'account-key'
        $result.Destination | Should -Match '/knowledgebases/Contoso$'
        Test-Path -LiteralPath (Join-Path $script:AzureRoot 'mcpposhstore/mcpposh/knowledgebases/Contoso/manifest.json') | Should -BeTrue
    }
}

Describe 'Serving the published knowledge base' {
    BeforeAll {
        $script:Port = Get-McpTestFreePort
        $script:Key = 'publish-key-' + [guid]::NewGuid().ToString('N')
        # Like the container, the server reads the knowledge base from the share.
        Start-McpServer -KnowledgeBase $script:Remote -Port $script:Port -ApiKey $script:Key | Out-Null
        $script:Base = "http://localhost:$($script:Port)"
    }

    AfterAll {
        Stop-McpServer -Port $script:Port -Confirm:$false -ErrorAction SilentlyContinue
    }

    It 'serves the published documents' {
        $result = Test-McpServer -Uri $script:Base -ApiKey $script:Key -Query 'nightly backup'
        $result.Success | Should -BeTrue -Because $result.Error
        $result.Documents | Should -Be 2
        $result.TopResult | Should -Be 'Backup'
    }

    It 'picks up a new publish while running' {
        Add-McpDocument -KnowledgeBase Contoso -Title 'Canteen' -Content 'The canteen menu hangs at the entrance.' | Out-Null
        Publish-McpKnowledgeBase -Name Contoso -StorageAccountName mcpposhstore -ShareName mcpposh -StorageAccountKey 'account-key' -RemoteName Docs | Out-Null
        Wait-McpTestCondition -TimeoutSeconds 30 -Because 'the server did not reload the published knowledge base' {
            (Test-McpServer -Uri $script:Base -ApiKey $script:Key -Query 'canteen menu').TopResult -eq 'Canteen'
        } | Should -BeTrue
    }
}
