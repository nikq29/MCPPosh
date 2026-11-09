function Get-McpHomePath {
    <#
    .SYNOPSIS
        Returns the MCPPosh data directory ($env:MCPPOSH_HOME or ~/.mcpposh) and creates it if needed.
    #>
    [CmdletBinding()]
    param()

    $path = if ($env:MCPPOSH_HOME) {
        $env:MCPPOSH_HOME
    }
    else {
        Join-Path -Path ([System.Environment]::GetFolderPath('UserProfile')) -ChildPath '.mcpposh'
    }
    $path = [System.IO.Path]::GetFullPath($path)
    if (-not [System.IO.Directory]::Exists($path)) {
        $null = [System.IO.Directory]::CreateDirectory($path)
    }
    $path
}
