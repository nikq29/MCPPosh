function Read-McpJsonFile {
    <#
    .SYNOPSIS
        Reads and parses a JSON file.

    .DESCRIPTION
        Reads a UTF-8 JSON file and parses it with ConvertFrom-McpJson. Returns $null when the file does not exist or is empty.

    .PARAMETER Path
        Path of the JSON file to read, for example a manifest.json or knowledgebase.json.

    .EXAMPLE
        Read-McpJsonFile -Path (Join-Path $kb.Path 'knowledgebase.json')

        Returns the knowledge base metadata as an ordered dictionary.
    #>
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
