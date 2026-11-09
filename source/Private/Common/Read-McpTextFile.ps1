function Read-McpTextFile {
    <#
    .SYNOPSIS
        Reads a text file as UTF-8 with retries.

    .DESCRIPTION
        Reads the complete content of a text file as UTF-8 (a byte order mark is detected and removed). Retries briefly when another process is replacing the file at the same moment.

    .PARAMETER Path
        Path of the text file to read, for example a document or index file of a knowledge base.

    .EXAMPLE
        Read-McpTextFile -Path (Join-Path $kb.Path 'documents/install-1a2b3c.md')

        Returns the Markdown content of the document.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $attempt = 0
    while ($true) {
        try {
            # ReadAllText detects and strips a BOM; UTF-8 is the fallback.
            return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
        }
        catch [System.IO.IOException] {
            if (++$attempt -ge 20) { throw }
            Start-Sleep -Milliseconds 50
        }
    }
}
