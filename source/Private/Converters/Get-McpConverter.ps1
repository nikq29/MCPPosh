function Get-McpConverter {
    <#
    .SYNOPSIS
        Finds the converter for a file (by extension or well-known file name) or by format name.
        Custom converters take precedence over built-in ones.
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
