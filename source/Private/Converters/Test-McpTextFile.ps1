function Test-McpTextFile {
    <#
    .SYNOPSIS
        Tests whether a file contains text.

    .DESCRIPTION
        Reads the first 8 KB of a file and returns $true when it contains no NUL bytes, which is a reliable heuristic to tell text files from binary files.

    .PARAMETER Path
        Path of the file to inspect.

    .EXAMPLE
        Test-McpTextFile -Path ./notes.unknown

        Returns $true for text files and $false for binary files.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $buffer = [byte[]]::new(8192)
        $read = $stream.Read($buffer, 0, $buffer.Length)
        for ($i = 0; $i -lt $read; $i++) {
            if ($buffer[$i] -eq 0) { return $false }
        }
        return $true
    }
    finally {
        $stream.Dispose()
    }
}
