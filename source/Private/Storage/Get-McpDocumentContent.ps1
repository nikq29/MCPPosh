function Get-McpDocumentContent {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $KbPath,

        [Parameter(Mandatory)]
        [string] $Id
    )

    $paths = Get-McpDocumentPath -KbPath $KbPath -Id $Id
    if (-not (Test-Path -LiteralPath $paths.Content -PathType Leaf)) {
        return $null
    }
    Read-McpTextFile -Path $paths.Content
}
