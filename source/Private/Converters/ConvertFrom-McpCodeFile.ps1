function ConvertFrom-McpCodeFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [string] $Language,

        [string] $Format = 'Code'
    )

    if (-not $Language) {
        $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
        $fileName = [System.IO.Path]::GetFileName($Path).ToLowerInvariant()
        $Language = if ($script:McpCodeLanguages.ContainsKey($extension)) { $script:McpCodeLanguages[$extension] }
        elseif ($script:McpCodeFileNames.ContainsKey($fileName)) { $script:McpCodeFileNames[$fileName] }
        else { '' }
    }

    $code = (Read-McpTextFile -Path $Path).TrimEnd()
    $fence = Get-McpCodeFence -Text $code
    $fileName = [System.IO.Path]::GetFileName($Path)
    @{
        Content = "# $fileName`n`n$fence$Language`n$code`n$fence`n"
        Title   = $fileName
        Format  = $Format
    }
}
