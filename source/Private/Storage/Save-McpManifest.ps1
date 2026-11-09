function Save-McpManifest {
    <#
    .SYNOPSIS
        Writes the manifest of a knowledge base with a new revision.

    .DESCRIPTION
        Increments the revision of a manifest, sets its updated timestamp and writes it atomically to manifest.json. Running servers detect the change and reload the search index.

    .PARAMETER KbPath
        Directory of the knowledge base whose manifest.json is written.

    .PARAMETER Manifest
        The manifest as an ordered dictionary, as returned by Read-McpManifest.

    .EXAMPLE
        $manifest = Read-McpManifest -KbPath $kb.Path
        Save-McpManifest -KbPath $kb.Path -Manifest $manifest

        Writes the manifest with an incremented revision.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $KbPath,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Manifest
    )

    $Manifest['revision'] = [long]$Manifest['revision'] + 1
    $Manifest['updated'] = Get-McpUtcNow
    Write-McpJsonFile -Path (Join-Path -Path $KbPath -ChildPath 'manifest.json') -InputObject $Manifest
}
