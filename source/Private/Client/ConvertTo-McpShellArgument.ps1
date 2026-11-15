function ConvertTo-McpShellArgument {
    <#
    .SYNOPSIS
        Quotes a value for use in a shell command line.

    .DESCRIPTION
        Returns the value unchanged when it only contains safe characters, otherwise wraps it in single quotes so the shell expands nothing: PowerShell quoting ('' for a quote) on Windows, POSIX quoting ('\'' for a quote) elsewhere. Used for the claude mcp add command.

    .PARAMETER Value
        The command-line argument to quote.

    .PARAMETER Shell
        PowerShell or Posix. Defaults to PowerShell on Windows and Posix on Linux and macOS.

    .EXAMPLE
        ConvertTo-McpShellArgument -Value 'Import-Module PSMcpKnowledgeBase; Start-McpServer'

        Returns 'Import-Module PSMcpKnowledgeBase; Start-McpServer' (in single quotes).

    .EXAMPLE
        ConvertTo-McpShellArgument -Value "C:\Docs\It's here" -Shell PowerShell

        Returns 'C:\Docs\It''s here'.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string] $Value,

        [ValidateSet('PowerShell', 'Posix')]
        [string] $Shell = $(if ($IsWindows) { 'PowerShell' } else { 'Posix' })
    )

    if ($Value -match '^[\w./:=@-]+$') { return $Value }
    # Single quotes in both shells: no variable, subexpression or escape character is expanded inside them.
    # PowerShell also ends single-quoted strings at the curly quotes U+2018-U+201B; this escapes all of them.
    if ($Shell -eq 'PowerShell') { return "'" + [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($Value) + "'" }
    "'" + $Value.Replace("'", "'\''") + "'"
}
