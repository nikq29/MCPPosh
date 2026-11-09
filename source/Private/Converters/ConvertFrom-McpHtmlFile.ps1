function ConvertFrom-McpHtmlFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    ConvertFrom-McpHtml -Html (Read-McpTextFile -Path $Path)
}
