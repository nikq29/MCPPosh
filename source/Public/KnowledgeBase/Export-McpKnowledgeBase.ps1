function Export-McpKnowledgeBase {
    <#
    .SYNOPSIS
        Exports a knowledge base to a ZIP archive (backup or transfer to another machine).
    .DESCRIPTION
        The archive contains the knowledge base metadata, manifest, documents and search index.
        Logs and lock files are not included. Restore it with Import-McpKnowledgeBase.
    .EXAMPLE
        Export-McpKnowledgeBase -Name Contoso -DestinationPath .\contoso-kb.zip
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [string] $Name,

        [Parameter(Mandatory, Position = 1)]
        [string] $DestinationPath,

        [switch] $Force
    )

    process {
        $kb = Resolve-McpKnowledgeBase -KnowledgeBase $Name
        $target = [System.IO.Path]::GetFullPath($DestinationPath, (Get-Location -PSProvider FileSystem).ProviderPath)
        if ((Test-Path -LiteralPath $target) -and -not $Force) {
            throw "'$target' already exists. Use -Force to overwrite it."
        }
        if (-not $PSCmdlet.ShouldProcess($target, "Export knowledge base '$($kb.Name)'")) { return }

        $files = Get-McpKnowledgeBaseFile -KbPath $kb.Path
        Invoke-McpKnowledgeBaseLock -KbPath $kb.Path -ScriptBlock {
            if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force }
            $directory = [System.IO.Path]::GetDirectoryName($target)
            if (-not [System.IO.Directory]::Exists($directory)) { $null = [System.IO.Directory]::CreateDirectory($directory) }
            $archive = [System.IO.Compression.ZipFile]::Open($target, [System.IO.Compression.ZipArchiveMode]::Create)
            try {
                foreach ($file in $files) {
                    $null = [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullPath, $file.RelativePath, [System.IO.Compression.CompressionLevel]::Optimal)
                }
            }
            finally {
                $archive.Dispose()
            }
        }
        Get-Item -LiteralPath $target
    }
}
