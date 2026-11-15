function Import-McpKnowledgeBase {
    <#
    .SYNOPSIS
        Imports a knowledge base from a ZIP archive created by Export-McpKnowledgeBase.

    .DESCRIPTION
        Restores a knowledge base from a ZIP archive created by Export-McpKnowledgeBase, optionally under a new name. Only knowledge base files are extracted and paths are validated. Archives with invalid document ids, more than 100000 entries or more than 1 GB of uncompressed content are rejected.

        Documents that were added from files or URLs keep their content but get the source type Imported, so Update-McpDocument never reads their source again: the author of an archive chooses these paths and URLs, and updating them would copy local files or responses of internal URLs into the knowledge base. Use -TrustSource to keep the source types of archives you created yourself, for example when you restore a backup on the same machine.

    .PARAMETER Path
        Path of the ZIP archive created by Export-McpKnowledgeBase. Accepts the FullName property of files through the pipeline.

    .PARAMETER Name
        Name for the imported knowledge base. Defaults to the name stored in the archive.

    .PARAMETER Force
        Replace an existing knowledge base with the same name.

    .PARAMETER TrustSource
        Keep the source types File and Url and the source hashes from the archive, so Update-McpDocument reads the source files and URLs again. Only use it for archives you created yourself: Update-McpDocument reads any path and URL stored in the archive.

    .EXAMPLE
        Import-McpKnowledgeBase -Path .\contoso-kb.zip

        Restores the knowledge base from the archive under the name stored in the archive.

    .EXAMPLE
        Import-McpKnowledgeBase -Path .\contoso-kb.zip -Name ContosoTest

        Imports the archive as a new knowledge base ContosoTest, for example to test changes.

    .EXAMPLE
        Import-McpKnowledgeBase -Path .\contoso-kb.zip -Force -TrustSource

        Restores your own backup and keeps the file and URL sources, so Update-McpDocument -All can update the documents again.

    .INPUTS
        System.String. You can pipe file objects; their FullName property binds to -Path.

    .OUTPUTS
        PSMcpKnowledgeBase.KnowledgeBase: Name, Description, Documents, Characters, Tags, Revision, Created, Updated and Path.

    .LINK
        https://github.com/nikq29/PSMcpKnowledgeBase/blob/main/docs/en-US/Import-McpKnowledgeBase.md

    .LINK
        Export-McpKnowledgeBase

    .LINK
        Get-McpKnowledgeBase
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType('PSMcpKnowledgeBase.KnowledgeBase')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string] $Path,

        [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')]
        [string] $Name,

        [switch] $Force,

        [switch] $TrustSource
    )

    process {
        $source = [System.IO.Path]::GetFullPath($Path, (Get-Location -PSProvider FileSystem).ProviderPath)
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            throw "Archive '$source' was not found."
        }

        $staging = Join-Path -Path (Get-McpKnowledgeBaseRoot) -ChildPath ('.import-' + [guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $staging -Force
        try {
            $stagingRoot = [System.IO.Path]::GetFullPath($staging) + [System.IO.Path]::DirectorySeparatorChar
            $archive = [System.IO.Compression.ZipFile]::OpenRead($source)
            try {
                if ($archive.Entries.Count -gt $script:McpMaxArchiveEntries) {
                    throw "'$source' contains more than $($script:McpMaxArchiveEntries) entries."
                }
                $extractedBytes = 0L
                foreach ($entry in $archive.Entries) {
                    if (-not $entry.Name) { continue }
                    $relative = $entry.FullName.Replace('\', '/')
                    if ($relative -notmatch '^(knowledgebase\.json|manifest\.json|documents/[^/]+|index/[^/]+)$') {
                        Write-Verbose "Skipping unexpected archive entry '$relative'"
                        continue
                    }
                    $destination = [System.IO.Path]::GetFullPath((Join-Path -Path $staging -ChildPath $relative))
                    if (-not $destination.StartsWith($stagingRoot, [System.StringComparison]::Ordinal)) {
                        throw "Archive entry '$relative' points outside the target folder."
                    }
                    $null = [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($destination))
                    # Count the bytes actually decompressed instead of trusting the sizes stored in the archive.
                    $entryStream = $entry.Open()
                    $fileStream = [System.IO.File]::Create($destination)
                    try {
                        $extractedBytes += Copy-McpStreamWithLimit -Source $entryStream -Destination $fileStream -MaxBytes ($script:McpMaxArchiveBytes - $extractedBytes) -Description "uncompressed content of '$source'"
                    }
                    finally {
                        $fileStream.Dispose()
                        $entryStream.Dispose()
                    }
                }
            }
            finally {
                $archive.Dispose()
            }

            $metaPath = Join-Path -Path $staging -ChildPath 'knowledgebase.json'
            if (-not (Test-Path -LiteralPath $metaPath) -or -not (Test-Path -LiteralPath (Join-Path $staging 'manifest.json'))) {
                throw "'$source' is not a PSMcpKnowledgeBase knowledge base archive (knowledgebase.json or manifest.json is missing)."
            }
            # Document ids become file names; reject manifests whose ids could address files outside the
            # knowledge base (for example '../../secret' or absolute paths).
            $manifest = Read-McpManifest -KbPath $staging
            foreach ($document in @($manifest['documents'])) {
                if (-not (Test-McpDocumentId -Id ([string]$document.id))) {
                    throw "'$source' contains the invalid document id '$($document.id)'. Document ids only contain letters, digits, '_' and '-'."
                }
            }
            # Update-McpDocument reads the source of File and Url documents again. The author of an archive chooses
            # these sources, so an archive could make it copy any file readable by the current user (or the response
            # of any URL reachable from this machine) into the knowledge base, where every agent can read it. Unless
            # the archive is trusted, documents keep their content but become Imported documents that are never
            # read from their source again. Everything except the known types without a source is converted, so
            # unknown, differently cased or non-string types cannot reach the File or Url branch either.
            $converted = 0
            if (-not $TrustSource) {
                foreach ($document in @($manifest['documents'])) {
                    $type = $document['sourceType']
                    if ($type -is [string] -and $type -cin 'Inline', 'Agent', 'Imported') { continue }
                    $document['sourceType'] = 'Imported'
                    $document.Remove('sourceHash')
                    $converted++
                }
                if ($converted -gt 0) {
                    Write-McpJsonFile -Path (Join-Path -Path $staging -ChildPath 'manifest.json') -InputObject $manifest
                }
            }
            $meta = Read-McpJsonFile -Path $metaPath
            $targetName = if ($Name) { $Name } else { [string]$meta.name }
            if (-not (Test-McpKnowledgeBaseName -Name $targetName)) {
                throw "The archive contains the invalid knowledge base name '$targetName'. Use -Name."
            }
            $target = Join-Path -Path (Get-McpKnowledgeBaseRoot) -ChildPath $targetName

            if (Test-Path -LiteralPath $target) {
                if (-not $Force) {
                    throw "Knowledge base '$targetName' already exists. Use -Force to replace it or -Name to import it under another name."
                }
                if (-not $PSCmdlet.ShouldProcess($targetName, 'Replace existing knowledge base')) { return }
                Remove-Item -LiteralPath $target -Recurse -Force
            }
            elseif (-not $PSCmdlet.ShouldProcess($targetName, 'Import knowledge base')) {
                return
            }

            if ($meta.name -ne $targetName) {
                $meta['name'] = $targetName
                Write-McpJsonFile -Path $metaPath -InputObject $meta
            }
            foreach ($folder in 'documents', 'index', 'logs') {
                $null = New-Item -ItemType Directory -Path (Join-Path $staging $folder) -Force
            }
            Move-Item -LiteralPath $staging -Destination $target
            if ($converted -gt 0) {
                Write-Warning ("{0} document(s) from '{1}' were imported with the source type Imported and are not updated from their source files or URLs. Use -TrustSource for archives you created yourself, or add the sources again with Add-McpDocument." -f $converted, $source)
            }
            $script:McpIndexCache.Remove($target)
            ConvertTo-McpKnowledgeBaseObject -KnowledgeBase (Resolve-McpKnowledgeBase -KnowledgeBase $targetName)
        }
        finally {
            if (Test-Path -LiteralPath $staging) {
                Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
