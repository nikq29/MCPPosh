function Get-McpHomePath {
    <#
    .SYNOPSIS
        Returns the PSMcpKnowledgeBase data directory ($env:PSMCPKB_HOME or ~/.psmcpkb) and creates it if needed.

    .DESCRIPTION
        Returns the full path of the PSMcpKnowledgeBase data directory. It is $env:PSMCPKB_HOME when set, otherwise .psmcpkb in the user profile. The directory is created when it does not exist.

    .EXAMPLE
        Get-McpHomePath

        Returns for example /home/user/.psmcpkb or C:\Users\user\.psmcpkb.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $path = if ($env:PSMCPKB_HOME) {
        $env:PSMCPKB_HOME
    }
    else {
        Join-Path -Path ([System.Environment]::GetFolderPath('UserProfile')) -ChildPath '.psmcpkb'
    }
    $path = [System.IO.Path]::GetFullPath($path)
    if (-not [System.IO.Directory]::Exists($path)) {
        $null = [System.IO.Directory]::CreateDirectory($path)
    }
    $path
}
