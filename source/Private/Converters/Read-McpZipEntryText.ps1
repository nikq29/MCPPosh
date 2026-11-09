function Read-McpZipEntryText {
    <#
    .SYNOPSIS
        Reads a text entry from a ZIP archive.

    .DESCRIPTION
        Returns the UTF-8 content of an entry of an opened ZIP archive, for example word/document.xml of a Word document, or $null when the entry does not exist.

    .PARAMETER Archive
        The opened System.IO.Compression.ZipArchive to read from.

    .PARAMETER EntryName
        Full name of the archive entry to read, for example word/document.xml.

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
