function Read-McpZipEntryText {
    <#
    .SYNOPSIS
        Reads a text entry from a ZIP archive.

    .DESCRIPTION
        Returns the UTF-8 content of an entry of an opened ZIP archive, for example word/document.xml of a Word document, or $null when the entry does not exist. Throws when the decompressed entry is larger than MaxBytes (protection against decompression bombs).

    .PARAMETER Archive
        The opened System.IO.Compression.ZipArchive to read from.

    .PARAMETER EntryName
        Full name of the archive entry to read, for example word/document.xml.

    .PARAMETER MaxBytes
        Maximum decompressed size of the entry in bytes; 64 MB by default.

    .EXAMPLE
        $archive = [System.IO.Compression.ZipFile]::OpenRead('./Handbook.docx')
        Read-McpZipEntryText -Archive $archive -EntryName 'word/document.xml'

        Returns the XML of the document body.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [System.IO.Compression.ZipArchive] $Archive,

        [Parameter(Mandatory)]
        [string] $EntryName,

        [ValidateRange(1, [long]::MaxValue)]
        [long] $MaxBytes = $script:McpMaxZipEntryBytes
    )

    $entry = $Archive.GetEntry($EntryName)
    if (-not $entry) { return $null }
    $buffer = [System.IO.MemoryStream]::new()
    $entryStream = $entry.Open()
    try {
        $null = Copy-McpStreamWithLimit -Source $entryStream -Destination $buffer -MaxBytes $MaxBytes -Description "archive entry '$EntryName'"
    }
    finally {
        $entryStream.Dispose()
    }
    $buffer.Position = 0
    $reader = [System.IO.StreamReader]::new($buffer, [System.Text.Encoding]::UTF8)
    try {
        $reader.ReadToEnd()
    }
    finally {
        $reader.Dispose()
    }
}
