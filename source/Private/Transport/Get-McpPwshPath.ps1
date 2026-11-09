function Get-McpPwshPath {
    <#
    .SYNOPSIS
        Returns the path of the PowerShell 7 executable.

    .DESCRIPTION
        Returns the path of pwsh in $PSHOME, or the first pwsh found on the PATH. Used to start background servers and stdio test processes, and in client configurations.

    .EXAMPLE
        Get-McpPwshPath

        Returns for example C:\Program Files\PowerShell\7\pwsh.exe.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $name = if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' }
    $candidate = Join-Path -Path $PSHOME -ChildPath $name
    if (Test-Path -LiteralPath $candidate) { return $candidate }
    $command = Get-Command -Name 'pwsh' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command.Source }
    throw 'Could not find pwsh (PowerShell 7). Make sure it is installed and on the PATH.'
}
