function Get-McpHomePath {
    <#
    .SYNOPSIS
        Returns the MCPPosh data directory ($env:MCPPOSH_HOME or ~/.mcpposh) and creates it if needed.

    .DESCRIPTION
        Returns the full path of the MCPPosh data directory. It is $env:MCPPOSH_HOME when set, otherwise .mcpposh in the user profile. The directory is created when it does not exist.

    .EXAMPLE
        Get-McpHomePath

        Returns for example /home/user/.mcpposh or C:\Users\user\.mcpposh.
    #>
    [CmdletBinding()]
    [OutputType([string])]
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
