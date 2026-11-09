function ConvertFrom-McpTextFile {
    <#
    .SYNOPSIS
        Reads a plain text file.

    .DESCRIPTION
        Reads a plain text file (for example .txt, .log, .rst or .adoc) without changes. The file name becomes the title.

    .PARAMETER Path
        Path of the text file to read. It is read as UTF-8.

    .EXAMPLE
        ConvertFrom-McpTextFile -Path ./notes.txt

        Returns a hashtable whose Content is the file content.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    @{ Content = Read-McpTextFile -Path $Path }
}
