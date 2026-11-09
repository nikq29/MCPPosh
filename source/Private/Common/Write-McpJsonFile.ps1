function Write-McpJsonFile {
    <#
    .SYNOPSIS
        Writes an object as a JSON file.

    .DESCRIPTION
        Serializes an object with ConvertTo-McpJson and writes it atomically as UTF-8 without byte order mark using Write-McpTextFile.

    .PARAMETER Path
        Path of the JSON file to write. The parent directory is created when needed.

    .PARAMETER InputObject
        The object to serialize, usually an ordered dictionary such as a manifest.

    .EXAMPLE
        Write-McpJsonFile -Path (Join-Path $kb.Path 'manifest.json') -InputObject $manifest

        Writes the manifest of a knowledge base.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $InputObject
    )

    Write-McpTextFile -Path $Path -Content (ConvertTo-McpJson -InputObject $InputObject)
}
