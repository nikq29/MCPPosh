function Get-McpPwshPath {
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
