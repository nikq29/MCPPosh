function Get-McpConverter {
    <#
    .SYNOPSIS
        Finds the converter for a file (by extension or well-known file name) or by format name.
        Custom converters take precedence over built-in ones.

    .DESCRIPTION
        Returns the converter for a file based on its extension or a well-known file name such as Dockerfile, or the converter with the given format name. Custom converters take precedence over built-in ones; unknown text files use the Text converter.

    .PARAMETER Path
        Path of the file for which a converter is selected by extension or file name.

    .PARAMETER Format
        Name of a converter to return instead of selecting it from the file path.

    .EXAMPLE
        Get-McpConverter -Path ./Handbook.docx

        Returns the built-in Docx converter.
    #>
    [CmdletBinding()]
    param(
        [string] $Path,

        [string] $Format
    )

    $converters = $script:McpConverters.ToArray()
    [array]::Reverse($converters)

    if ($Format) {
        $match = $converters | Where-Object { $_.Name -eq $Format } | Select-Object -First 1
        if (-not $match) {
            $names = ($script:McpConverters | ForEach-Object Name | Sort-Object -Unique) -join ', '
            throw "Unknown format '$Format'. Available formats: $names"
        }
        return $match
    }

    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    if ($extension) {
        $match = $converters | Where-Object { $_.Extensions -contains $extension } | Select-Object -First 1
        if ($match) { return $match }
    }

    $fileName = [System.IO.Path]::GetFileName($Path).ToLowerInvariant()
    if ($script:McpCodeFileNames.ContainsKey($fileName)) {
        return $converters | Where-Object { $_.Name -eq 'Code' } | Select-Object -First 1
    }

    if (Test-McpTextFile -Path $Path) {
        return $converters | Where-Object { $_.Name -eq 'Text' } | Select-Object -First 1
    }
    $null
}
