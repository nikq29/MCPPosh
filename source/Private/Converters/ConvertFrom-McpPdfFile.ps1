function ConvertFrom-McpPdfFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $text = Invoke-McpPdfTextExtraction -Path $Path
    $text = ([string]$text).Replace("`f", "`n`n")
    @{ Content = $text }
}
