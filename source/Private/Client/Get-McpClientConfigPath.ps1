function Get-McpClientConfigPath {
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
