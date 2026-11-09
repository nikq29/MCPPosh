function ConvertFrom-McpPdfFile {
    <#
    .SYNOPSIS
        Converts a PDF file to text.

    .DESCRIPTION
        Extracts the text of a PDF file with Invoke-McpPdfTextExtraction and turns page breaks (form feeds) into paragraph breaks.

    .PARAMETER Path
        Path of the PDF file to convert. Scanned PDFs without a text layer return little or no text.

    .EXAMPLE
        ConvertFrom-McpPdfFile -Path ./manual.pdf

        Returns a hashtable whose Content is the text of all pages.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $text = Invoke-McpPdfTextExtraction -Path $Path
    $text = ([string]$text).Replace("`f", "`n`n")
    @{ Content = $text }
}
