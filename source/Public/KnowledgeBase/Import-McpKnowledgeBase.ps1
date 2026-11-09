function Import-McpKnowledgeBase {
    <#
    .SYNOPSIS
        Imports a knowledge base from a ZIP archive created by Export-McpKnowledgeBase.

    .DESCRIPTION
        Restores a knowledge base from a ZIP archive created by Export-McpKnowledgeBase, optionally under a new name. Only knowledge base files are extracted and paths are validated.

    .PARAMETER Path
        Path of the ZIP archive created by Export-McpKnowledgeBase. Accepts the FullName property of files through the pipeline.

    .PARAMETER Name
        Name for the imported knowledge base. Defaults to the name stored in the archive.

    .PARAMETER Force
        Replace an existing knowledge base with the same name.

    .EXAMPLE
        Import-McpKnowledgeBase -Path .\contoso-kb.zip

        Restores the knowledge base from the archive under the name stored in the archive.

    .EXAMPLE
        Import-McpKnowledgeBase -Path .\contoso-kb.zip -Name ContosoTest

        Imports the archive as a new knowledge base ContosoTest, for example to test changes.

    .INPUTS
        System.String. You can pipe file objects; their FullName property binds to -Path.

    .OUTPUTS
        MCPPosh.KnowledgeBase: Name, Description, Documents, Characters, Tags, Revision, Created, Updated and Path.

    .LINK
        https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Import-McpKnowledgeBase.md

    .LINK
        Export-McpKnowledgeBase

    .LINK
        Get-McpKnowledgeBase
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType('MCPPosh.KnowledgeBase')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string] $Path,

        [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')]
        [string] $Name,

        [switch] $Force
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
                    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destination, $true)
                }
            }
            finally {
                $archive.Dispose()
            }

            $metaPath = Join-Path -Path $staging -ChildPath 'knowledgebase.json'
            if (-not (Test-Path -LiteralPath $metaPath) -or -not (Test-Path -LiteralPath (Join-Path $staging 'manifest.json'))) {
                throw "'$source' is not an MCPPosh knowledge base archive (knowledgebase.json or manifest.json is missing)."
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
