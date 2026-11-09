function Read-McpManifest {
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
