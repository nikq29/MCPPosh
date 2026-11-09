<#
    Example 2: Provide the knowledge base to an AI agent and manage the server.
#>
Import-Module MCPPosh

# --- Option A: stdio (the agent starts the server itself) ---------------------------------

# Claude Desktop: paste the JSON into claude_desktop_config.json
$config = Get-McpClientConfig -KnowledgeBase Contoso -Client ClaudeDesktop
$config.ConfigFile
$config.Json

# Claude Code: run the generated command
(Get-McpClientConfig -KnowledgeBase Contoso -Client ClaudeCode).Command

# VS Code (GitHub Copilot agent mode): .vscode/mcp.json in the project
Get-McpClientConfig -KnowledgeBase Contoso -Client VSCode -AsJson | Set-Content .vscode/mcp.json

# Let the agent write notes as well (tool add_note)
Get-McpClientConfig -KnowledgeBase Contoso -Client Cursor -AllowWrite -AsJson

# Test beforehand, exactly the way the agent starts the server
Test-McpServer -KnowledgeBase Contoso -Query 'VPN'

# --- Option B: HTTP server in the background -------------------------------------------

$key = 'please-use-a-long-random-key'
Start-McpServer -KnowledgeBase Contoso -Port 5050 -ApiKey $key -AllowWrite

Get-McpServer                                   # status, URL, process id, uptime
Test-McpServer -Uri http://localhost:5050/mcp -ApiKey $key -Query 'backup'
Get-McpServerLog -KnowledgeBase Contoso -Port 5050 -Tail 20

# New knowledge is available immediately, no restart needed
Add-McpDocument -KnowledgeBase Contoso -Title 'Printer change' -Content 'From December 1 the 3rd floor prints on PRN-07.'

Get-McpClientConfig -KnowledgeBase Contoso -Client VSCode -Transport Http -ApiKeyPlaceholder -AsJson

Restart-McpServer -KnowledgeBase Contoso -ApiKey $key
Stop-McpServer -KnowledgeBase Contoso
