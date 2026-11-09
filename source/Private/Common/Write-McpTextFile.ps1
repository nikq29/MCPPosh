function Write-McpTextFile {
    <#
    .SYNOPSIS
        Atomically writes UTF-8 text (no BOM): write to a temp file, then rename over the target.

    .DESCRIPTION
        Writes text as UTF-8 without byte order mark to a temporary file in the target directory and then renames it over the target, so readers such as a running server never see a partially written file. Retries while another process holds the target open.

    .PARAMETER Path
        Path of the file to write. The parent directory is created when it does not exist.

    .PARAMETER Content
        The text to write. An empty string creates an empty file.

    .EXAMPLE
        Write-McpTextFile -Path (Join-Path $kb.Path 'documents/note-1a2b3c.md') -Content "# Note

        Text"

        Writes a document atomically.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Content
    )

    $directory = [System.IO.Path]::GetDirectoryName($Path)
    if (-not [System.IO.Directory]::Exists($directory)) {
        $null = [System.IO.Directory]::CreateDirectory($directory)
    }
    $tempPath = [System.IO.Path]::Combine($directory, ('.{0}.{1}.tmp' -f [System.IO.Path]::GetFileName($Path), [guid]::NewGuid().ToString('N')))
    [System.IO.File]::WriteAllText($tempPath, $Content, $script:Utf8NoBom)

    $attempt = 0
    while ($true) {
        try {
            [System.IO.File]::Move($tempPath, $Path, $true)
            break
        }
        catch [System.IO.IOException], [System.UnauthorizedAccessException] {
            if (++$attempt -ge 40) {
                Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
                throw
            }
            Start-Sleep -Milliseconds 50
        }
    }
}
