function Publish-McpKnowledgeBase {
    <#
    .SYNOPSIS
        Publishes a local knowledge base to an Azure Files share used by a hosted PSMcpKnowledgeBase server.

    .DESCRIPTION
        Maintain your documentation locally with Add-McpDocument and publish it to the file share
        that the PSMcpKnowledgeBase container (e.g. in Azure Container Apps) mounts at /data. The running
        server picks up the new revision automatically.

        Only files that changed since the last publish are uploaded. The manifest is uploaded
        last so the server always sees a consistent state. -Prune removes documents from the
        share that no longer exist locally.

        Publishing stops when the share holds documents that do not exist locally and were not
        published from this computer, for example notes that agents saved on the server with
        add_note. Copy them to the local knowledge base first, or use -Force to replace them.

        Requires the Az.Storage module (Install-Module Az.Storage).

    .PARAMETER Name
        Name or directory path of the local knowledge base to publish.

    .PARAMETER StorageAccountName
        Storage account that holds the share.

    .PARAMETER ShareName
        Azure Files share mounted by the container (the Bicep template creates 'psmcpkb').

    .PARAMETER StorageAccountKey
        Access key of the storage account that holds the Azure Files share.

    .PARAMETER SasToken
        SAS token with read, write, create, list and delete permissions on the share.

    .PARAMETER ResourceGroupName
        Resource group of the storage account; the key is read with Get-AzStorageAccountKey
        (requires Connect-AzAccount).

    .PARAMETER Context
        An existing Azure Storage context (New-AzStorageContext).

    .PARAMETER RemoteName
        Knowledge base name on the share. Defaults to the local name; must match
        PSMCPKB_KNOWLEDGEBASE of the container.

    .PARAMETER Prune
        Delete documents on the share that no longer exist locally.

    .PARAMETER Force
        Upload all files, not only the changed ones, and replace documents that exist only on
        the share (for example agent notes) instead of stopping.

    .EXAMPLE
        Connect-AzAccount
        Publish-McpKnowledgeBase -Name Contoso -StorageAccountName psmcpkbab12cd -ShareName psmcpkb -ResourceGroupName rg-psmcpkb -Prune

        Uploads the changed files of the knowledge base Contoso to the Azure Files share of a hosted server and deletes documents that were removed locally. The storage key is read from the resource group.

    .EXAMPLE
        Publish-McpKnowledgeBase -Name Contoso -StorageAccountName psmcpkbab12cd -ShareName psmcpkb -SasToken $sas -RemoteName Docs

        Publishes with a SAS token into the knowledge base Docs on the share; the container must use PSMCPKB_KNOWLEDGEBASE=Docs.

    .INPUTS
        None. You cannot pipe objects to this cmdlet.

    .OUTPUTS
        PSMcpKnowledgeBase.PublishResult: KnowledgeBase, Destination, Uploaded, Skipped, Deleted and Revision.

    .LINK
        https://github.com/nikq29/PSMcpKnowledgeBase/blob/main/docs/en-US/Publish-McpKnowledgeBase.md

    .LINK
        Export-McpKnowledgeBase

    .LINK
        Get-McpServer

    .LINK
        Test-McpServer
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ResourceGroup')]
    [OutputType('PSMcpKnowledgeBase.PublishResult')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $Name,

        [Parameter(Mandatory, ParameterSetName = 'ResourceGroup')]
        [Parameter(Mandatory, ParameterSetName = 'Key')]
        [Parameter(Mandatory, ParameterSetName = 'Sas')]
        [string] $StorageAccountName,

        [Parameter(Mandatory)]
        [string] $ShareName,

        [Parameter(Mandatory, ParameterSetName = 'Key')]
        [string] $StorageAccountKey,

        [Parameter(Mandatory, ParameterSetName = 'Sas')]
        [string] $SasToken,

        [Parameter(Mandatory, ParameterSetName = 'ResourceGroup')]
        [string] $ResourceGroupName,

        [Parameter(Mandatory, ParameterSetName = 'Context')]
        [object] $Context,

        [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')]
        [string] $RemoteName,

        [switch] $Prune,

        [switch] $Force
    )

    $kb = Resolve-McpKnowledgeBase -KnowledgeBase $Name
    if (-not $RemoteName) { $RemoteName = $kb.Name }
    Assert-McpAzStorageModule

    $storageContext = switch ($PSCmdlet.ParameterSetName) {
        'Context' { $Context }
        'Key' { New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey }
        'Sas' { New-AzStorageContext -StorageAccountName $StorageAccountName -SasToken $SasToken }
        'ResourceGroup' {
            $keys = Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction Stop
            New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey (@($keys)[0].Value)
        }
    }
    $accountLabel = if ($StorageAccountName) { $StorageAccountName } elseif ($storageContext.StorageAccountName) { $storageContext.StorageAccountName } else { 'storage' }
    $remoteRoot = "knowledgebases/$RemoteName"
    $destination = "https://$accountLabel.file.core.windows.net/$ShareName/$remoteRoot"

    if (-not $PSCmdlet.ShouldProcess($destination, "Publish knowledge base '$($kb.Name)'")) { return }

    $stateFile = Join-Path -Path $kb.Path -ChildPath ('.publish/{0}.json' -f (ConvertTo-McpSlug -Text "$accountLabel-$ShareName-$RemoteName"))
    $previous = Read-McpJsonFile -Path $stateFile
    if ($null -eq $previous -or $Force) { $previous = [ordered]@{} }

    # Snapshot the local files under the lock so the published state is consistent.
    $snapshot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('psmcpkb-publish-' + [guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $snapshot -Force
    try {
        $kbLock = Lock-McpKnowledgeBase -KbPath $kb.Path
        try {
            $files = foreach ($file in (Get-McpKnowledgeBaseFile -KbPath $kb.Path)) {
                $copy = Join-Path -Path $snapshot -ChildPath $file.RelativePath
                $null = New-Item -ItemType Directory -Path ([System.IO.Path]::GetDirectoryName($copy)) -Force
                Copy-Item -LiteralPath $file.FullPath -Destination $copy
                [pscustomobject]@{ FullPath = $copy; RelativePath = $file.RelativePath; Hash = Get-McpSha256 -Path $copy }
            }
        }
        finally {
            $kbLock.Dispose()
        }

        foreach ($directory in 'knowledgebases', $remoteRoot, "$remoteRoot/documents", "$remoteRoot/index") {
            $existing = Get-AzStorageFile -ShareName $ShareName -Path $directory -Context $storageContext -ErrorAction SilentlyContinue
            if (-not $existing) {
                $null = New-AzStorageDirectory -ShareName $ShareName -Path $directory -Context $storageContext
            }
        }

        # Notes saved by agents on the server (add_note) exist only in the remote manifest, and uploading the local
        # manifest would drop them. Documents published from here before were removed locally on purpose.
        if (-not $Force) {
            $remoteManifestPath = Join-Path -Path $snapshot -ChildPath '.remote-manifest.json'
            $null = Get-AzStorageFileContent -ShareName $ShareName -Path "$remoteRoot/manifest.json" -Destination $remoteManifestPath -Context $storageContext -Force -ErrorAction SilentlyContinue
            $remoteManifest = Read-McpJsonFile -Path $remoteManifestPath
            $localIds = @((Read-McpManifest -KbPath $snapshot)['documents'] | ForEach-Object { [string]$_.id })
            $remoteOnly = @(@($remoteManifest.documents) | Where-Object { $_ -and $localIds -notcontains [string]$_.id -and -not $previous.Contains("documents/$($_.id).md") })
            if ($remoteOnly.Count -gt 0) {
                throw ("The share contains {0} document(s) that do not exist locally and were not published from here, for example notes saved by agents with add_note: {1}. Publishing would remove them from the server. Copy them to the local knowledge base first, or use -Force to replace them." -f $remoteOnly.Count, (($remoteOnly | ForEach-Object { "'$($_.title)' ($($_.id))" }) -join ', '))
            }
        }

        $uploaded = 0
        $skipped = 0
        $current = [ordered]@{}
        $ordered = @($files | Where-Object { $_.RelativePath -ne 'manifest.json' }) + @($files | Where-Object { $_.RelativePath -eq 'manifest.json' })
        foreach ($file in $ordered) {
            $current[$file.RelativePath] = $file.Hash
            if ($file.RelativePath -ne 'manifest.json' -and $previous[$file.RelativePath] -eq $file.Hash) {
                $skipped++
                continue
            }
            Write-Verbose "Uploading $($file.RelativePath)"
            $null = Set-AzStorageFileContent -ShareName $ShareName -Source $file.FullPath -Path "$remoteRoot/$($file.RelativePath)" -Context $storageContext -Force
            $uploaded++
        }

        $deleted = 0
        if ($Prune) {
            foreach ($folder in 'documents', 'index') {
                $remoteFiles = @(Get-AzStorageFile -ShareName $ShareName -Path "$remoteRoot/$folder" -Context $storageContext -ErrorAction SilentlyContinue | Get-AzStorageFile -ErrorAction SilentlyContinue)
                foreach ($remoteFile in $remoteFiles) {
                    $relative = "$folder/$($remoteFile.Name)"
                    if ($current.Contains($relative)) { continue }
                    Write-Verbose "Deleting $relative"
                    Remove-AzStorageFile -ShareName $ShareName -Path "$remoteRoot/$relative" -Context $storageContext
                    $deleted++
                }
            }
        }

        Write-McpJsonFile -Path $stateFile -InputObject $current
        [pscustomobject]@{
            PSTypeName    = 'PSMcpKnowledgeBase.PublishResult'
            KnowledgeBase = $kb.Name
            Destination   = $destination
            Uploaded      = $uploaded
            Skipped       = $skipped
            Deleted       = $deleted
            Revision      = [long](Read-McpManifest -KbPath $kb.Path)['revision']
        }
    }
    finally {
        Remove-Item -LiteralPath $snapshot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
