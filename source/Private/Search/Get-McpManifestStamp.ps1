function Get-McpManifestStamp {
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
