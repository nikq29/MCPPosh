function Get-McpDocumentConverter {
    <#
    .SYNOPSIS
        Lists the available document converters (formats) and their file extensions.
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
