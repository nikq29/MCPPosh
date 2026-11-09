function Save-McpManifest {
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
