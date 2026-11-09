function Get-McpDocumentConverter {
    <#
    .SYNOPSIS
        Lists the available document converters (formats) and their file extensions.

    .DESCRIPTION
        Lists the built-in and custom document converters that Add-McpDocument uses to turn files into Markdown, together with the file extensions each converter handles.

    .PARAMETER Name
        Name of the converter to return. Wildcards are supported; all converters are returned by default.

    .PARAMETER Extension
        Only return the converter that handles this file extension, for example .docx or docx.

    .EXAMPLE
        Get-McpDocumentConverter

    .EXAMPLE
        Get-McpDocumentConverter -Extension .docx
    #>
    [CmdletBinding()]
    [OutputType('MCPPosh.Converter')]
    param(
        [Parameter(Position = 0)]
        [SupportsWildcards()]
        [string] $Name = '*',

        [string] $Extension
    )

    $normalized = if ($Extension) {
        $value = $Extension.Trim().ToLowerInvariant()
        if ($value.StartsWith('.')) { $value } else { ".$value" }
    }

    $script:McpConverters.ToArray() | Where-Object {
        $_.Name -like $Name -and (-not $normalized -or $_.Extensions -contains $normalized)
    }
}
