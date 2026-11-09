function ConvertTo-McpShellArgument {
    <#
    .SYNOPSIS
        Quotes a value for use in a shell command line.

    .DESCRIPTION
        Returns the value unchanged when it only contains safe characters, otherwise wraps it in quotes for the current platform (double quotes on Windows, single quotes elsewhere). Used for the claude mcp add command.

    .PARAMETER Value
        The command-line argument to quote.

    .EXAMPLE
        ConvertTo-McpShellArgument -Value 'Import-Module MCPPosh; Start-McpServer'

        Returns 'Import-Module MCPPosh; Start-McpServer' on Linux and macOS.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string] $Value
    )

    if ($Value -match '^[\w./:=@-]+$') { return $Value }
    if ($IsWindows) { return '"' + $Value.Replace('"', '\"') + '"' }
    "'" + $Value.Replace("'", "'\''") + "'"
}
