function Get-McpClientConfigPath {
    <#
    .SYNOPSIS
        Returns the configuration file location of an AI client.

    .DESCRIPTION
        Returns where the configuration of an AI client is stored on the current platform, for example claude_desktop_config.json for Claude Desktop, so users know where to paste the generated JSON.

    .PARAMETER Client
        The AI client: ClaudeDesktop, ClaudeCode, VSCode, Cursor or Generic.

    .EXAMPLE
        Get-McpClientConfigPath -Client ClaudeDesktop

        Returns for example %APPDATA%\Claude\claude_desktop_config.json on Windows.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Client
    )

    switch ($Client) {
        'ClaudeDesktop' {
            if ($IsWindows) { Join-Path $env:APPDATA 'Claude/claude_desktop_config.json' }
            elseif ($IsMacOS) { Join-Path $HOME 'Library/Application Support/Claude/claude_desktop_config.json' }
            else { Join-Path $HOME '.config/Claude/claude_desktop_config.json' }
        }
        'ClaudeCode' { '.mcp.json (project) or: claude mcp add' }
        'VSCode' { '.vscode/mcp.json (workspace) or the user-level mcp.json (MCP: Open User Configuration)' }
        'Cursor' { Join-Path $HOME '.cursor/mcp.json' }
        default { $null }
    }
}
