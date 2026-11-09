function Read-McpZipEntryText {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [System.IO.Compression.ZipArchive] $Archive,

        [Parameter(Mandatory)]
        [string] $EntryName
    )

    $entry = $Archive.GetEntry($EntryName)
    if (-not $entry) { return $null }
    $reader = [System.IO.StreamReader]::new($entry.Open(), [System.Text.Encoding]::UTF8)
    try {
        $reader.ReadToEnd()
    }
    finally {
        $reader.Dispose()
    }
}
