function Get-McpManifestStamp {
    <#
    .SYNOPSIS
        Returns a change stamp of the manifest of a knowledge base.

    .DESCRIPTION
        Returns the last write time and the size of manifest.json as a string. The search index cache and running servers compare this stamp to detect changes cheaply.

    .PARAMETER KbPath
        Directory of the knowledge base whose manifest.json is checked.

    .EXAMPLE
        Get-McpManifestStamp -KbPath $kb.Path

        Returns for example 639036612345678901-2311, or 0 when there is no manifest.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $KbPath
    )

    $file = [System.IO.FileInfo]::new([System.IO.Path]::Combine($KbPath, 'manifest.json'))
    $file.Refresh()
    if (-not $file.Exists) { return '0' }
    '{0}-{1}' -f $file.LastWriteTimeUtc.Ticks, $file.Length
}
