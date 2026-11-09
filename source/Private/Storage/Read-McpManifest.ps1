function Read-McpManifest {
    <#
    .SYNOPSIS
        Reads the manifest of a knowledge base.

    .DESCRIPTION
        Reads manifest.json of a knowledge base and returns it as an ordered dictionary with schemaVersion, revision, updated and the documents array. Returns an empty manifest when the file does not exist.

    .PARAMETER KbPath
        Directory of the knowledge base whose manifest.json is read.

    .EXAMPLE
        (Read-McpManifest -KbPath $kb.Path).documents.Count

        Returns the number of documents in the knowledge base.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $KbPath
    )

    $manifest = Read-McpJsonFile -Path (Join-Path -Path $KbPath -ChildPath 'manifest.json')
    if ($null -eq $manifest) {
        $manifest = [ordered]@{ schemaVersion = 1; revision = 0; updated = $null; documents = @() }
    }
    if ($null -eq $manifest['documents']) {
        $manifest['documents'] = @()
    }
    $manifest
}
