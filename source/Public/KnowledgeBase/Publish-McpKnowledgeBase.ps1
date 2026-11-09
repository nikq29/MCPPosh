function Publish-McpKnowledgeBase {
    <#
    .SYNOPSIS
        Publishes a local knowledge base to an Azure Files share used by a hosted MCPPosh server.
    .DESCRIPTION
        Maintain your documentation locally with Add-McpDocument and publish it to the file share
        that the MCPPosh container (e.g. in Azure Container Apps) mounts at /data. The running
        server picks up the new revision automatically.

        Only files that changed since the last publish are uploaded. The manifest is uploaded
        last so the server always sees a consistent state. -Prune removes documents from the
        share that no longer exist locally.

        Requires the Az.Storage module (Install-Module Az.Storage).
    .PARAMETER Name
        Local knowledge base.
    .PARAMETER StorageAccountName
        Storage account that holds the share.
    .PARAMETER ShareName
        Azure Files share mounted by the container (the Bicep template creates 'mcpposh').
    .PARAMETER StorageAccountKey
        Storage account key.
    .PARAMETER SasToken
        SAS token with read, write, create, list and delete permissions on the share.
    .PARAMETER ResourceGroupName
        Resource group of the storage account; the key is read with Get-AzStorageAccountKey
        (requires Connect-AzAccount).
    .PARAMETER Context
        An existing Azure Storage context (New-AzStorageContext).
    .PARAMETER RemoteName
        Knowledge base name on the share. Defaults to the local name; must match
        MCPPOSH_KNOWLEDGEBASE of the container.
    .PARAMETER Prune
        Delete documents on the share that no longer exist locally.
    .PARAMETER Force
        Upload all files, not only the changed ones.
    .EXAMPLE
        Connect-AzAccount
        Publish-McpKnowledgeBase -Name Contoso -StorageAccountName mcpposhab12cd -ShareName mcpposh -ResourceGroupName rg-mcpposh -Prune
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ResourceGroup')]
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
    $snapshot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('mcpposh-publish-' + [guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $snapshot -Force
    try {
        $files = Invoke-McpKnowledgeBaseLock -KbPath $kb.Path -ScriptBlock {
            foreach ($file in (Get-McpKnowledgeBaseFile -KbPath $kb.Path)) {
                $copy = Join-Path -Path $snapshot -ChildPath $file.RelativePath
                $null = New-Item -ItemType Directory -Path ([System.IO.Path]::GetDirectoryName($copy)) -Force
                Copy-Item -LiteralPath $file.FullPath -Destination $copy
                [pscustomobject]@{ FullPath = $copy; RelativePath = $file.RelativePath; Hash = Get-McpSha256 -Path $copy }
            }
        }

        foreach ($directory in 'knowledgebases', $remoteRoot, "$remoteRoot/documents", "$remoteRoot/index") {
            $existing = Get-AzStorageFile -ShareName $ShareName -Path $directory -Context $storageContext -ErrorAction SilentlyContinue
            if (-not $existing) {
                $null = New-AzStorageDirectory -ShareName $ShareName -Path $directory -Context $storageContext
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
