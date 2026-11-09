function Invoke-McpPdfTextExtraction {
    <#
    .SYNOPSIS
        Extracts text from a PDF using PSWritePDF (preferred) or pdftotext (Poppler).

    .DESCRIPTION
        Extracts the text of a PDF with Convert-PDFToText from the PSWritePDF module when it is installed, otherwise with the pdftotext tool from Poppler. Throws an error with installation instructions when neither is available.

    .PARAMETER Path
        Path of the PDF file whose text is extracted.

    .EXAMPLE
        Invoke-McpPdfTextExtraction -Path ./manual.pdf

        Returns the text of the PDF.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    if (Get-Module -ListAvailable -Name PSWritePDF) {
        Import-Module -Name PSWritePDF -ErrorAction Stop -Verbose:$false
        $pages = Convert-PDFToText -FilePath $Path
        return (@($pages) | ForEach-Object { [string]$_ }) -join "`n`n"
    }

    $pdftotext = Get-Command -Name 'pdftotext' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pdftotext) {
        $output = & $pdftotext.Source -layout -enc UTF-8 $Path - 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "pdftotext failed with exit code $LASTEXITCODE for '$Path'."
        }
        return (@($output) -join "`n")
    }

    throw ("PDF support requires the PowerShell module 'PSWritePDF' (Install-Module PSWritePDF -Scope CurrentUser) " +
        "or the 'pdftotext' tool from Poppler (Windows: winget install oschwartz10612.Poppler, macOS: brew install poppler, Linux: apt install poppler-utils).")
}
