function Read-McpJsonFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }
    $text = Read-McpTextFile -Path $Path
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }
    ConvertFrom-McpJson -Json $text
}
