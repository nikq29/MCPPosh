function Get-McpServerStateRoot {
    [CmdletBinding()]
    param()

    $path = Join-Path -Path (Get-McpHomePath) -ChildPath 'servers'
    if (-not [System.IO.Directory]::Exists($path)) {
        $null = [System.IO.Directory]::CreateDirectory($path)
    }
    $path
}
