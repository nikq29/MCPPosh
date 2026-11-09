# Client configuration

`Get-McpClientConfig` creates the configuration that connects an AI client to an MCPPosh server, either over stdio
(the client starts the server) or over HTTP (the client connects to a running server).

```powershell
Get-McpClientConfig -KnowledgeBase Contoso -Client ClaudeDesktop
```

The result contains:

| Property | Content |
| --- | --- |
| `Client` | the client the configuration was created for |
| `Transport` | `Stdio` or `Http` |
| `ServerName` | name of the server entry, by default `mcpposh-<knowledge base>` |
| `ConfigFile` | where the client expects its configuration |
| `Json` | the configuration as JSON |
| `Command` | for Claude Code: the `claude mcp add` command |
| `Notes` | hints, for example when an API key is written in plain text |

`-AsJson` returns only the JSON text, `-ServerName` changes the entry name.

## stdio

With stdio the client starts `pwsh` and runs `Start-McpServer -Transport Stdio`. The generated arguments are
`-NoLogo -NoProfile -NonInteractive -Command "Import-Module …; Start-McpServer -KnowledgeBase '…' -Transport Stdio"`.

- When MCPPosh is installed in a standard module folder (for example with `Install-PSResource`), the module is
  imported by name, so the configuration keeps working after updates. Otherwise the full path of the module
  manifest is used. `-UseModuleName` forces the import by name.
- When `$env:MCPPOSH_HOME` is set, it is added to the `env` section of the entry.
- `-AllowWrite` adds `-AllowWrite`, so the agent gets the `add_note` tool.
- The full path of `pwsh` is used, because some clients (for example Claude Desktop on macOS) do not inherit the
  `PATH` of your shell.

### Claude Desktop

```powershell
$config = Get-McpClientConfig -KnowledgeBase Contoso -Client ClaudeDesktop
$config.ConfigFile   # Windows: %APPDATA%\Claude\claude_desktop_config.json
$config.Json
```

Merge the entry under `mcpServers` into the configuration file and restart Claude Desktop:

```json
{
  "mcpServers": {
    "mcpposh-contoso": {
      "command": "C:\\Program Files\\PowerShell\\7\\pwsh.exe",
      "args": ["-NoLogo", "-NoProfile", "-NonInteractive", "-Command",
               "Import-Module MCPPosh; Start-McpServer -KnowledgeBase 'Contoso' -Transport Stdio"]
    }
  }
}
```

Configuration file locations: Windows `%APPDATA%\Claude\claude_desktop_config.json`, macOS
`~/Library/Application Support/Claude/claude_desktop_config.json`, Linux `~/.config/Claude/claude_desktop_config.json`.

### Claude Code

```powershell
(Get-McpClientConfig -KnowledgeBase Contoso -Client ClaudeCode).Command
```

Run the returned `claude mcp add mcpposh-contoso -- pwsh …` command, or put the JSON into the `.mcp.json` file of your
project to share the server with your team.

### VS Code (GitHub Copilot)

```powershell
Get-McpClientConfig -KnowledgeBase Contoso -Client VSCode -AsJson | Set-Content .vscode/mcp.json
```

VS Code uses the key `servers` and `"type": "stdio"`. For a user-wide configuration run the command
*MCP: Open User Configuration* in VS Code and merge the entry there.

### Cursor

```powershell
Get-McpClientConfig -KnowledgeBase Contoso -Client Cursor -AsJson
```

Merge the entry into `~/.cursor/mcp.json` (global) or `.cursor/mcp.json` in a project.

### Other clients

`-Client Generic` (the default) creates the common `mcpServers` format with `command` and `args`, which most other
MCP clients understand.

## HTTP

With `-Transport Http` the client connects to a running server. Without `-Uri` the URL of the running local HTTP
server of the knowledge base is used.

```powershell
Get-McpClientConfig -KnowledgeBase Contoso -Client VSCode -Transport Http -ApiKeyPlaceholder
Get-McpClientConfig -KnowledgeBase Contoso -Client Cursor -Transport Http -Uri https://mcpposh.example.com/mcp -ApiKey $key
(Get-McpClientConfig -KnowledgeBase Contoso -Client ClaudeCode -Transport Http -Uri https://mcpposh.example.com -ApiKey $key).Command
```

A base URL such as `https://mcpposh.example.com` is completed to `https://mcpposh.example.com/mcp`.

### API keys

- `-ApiKey` writes the key into the configuration (`Authorization: Bearer <key>`). The result contains a note,
  because the key is then stored in plain text.
- `-ApiKeyPlaceholder` writes a reference instead of the key:

| Client | Placeholder | How the key is provided |
| --- | --- | --- |
| VS Code | `${input:mcpposh-api-key}` | VS Code prompts for the key once and stores it securely (an `inputs` entry is added) |
| Claude Code | `${MCPPOSH_API_KEY}` | environment variable |
| Cursor | `${env:MCPPOSH_API_KEY}` | environment variable |
| Generic | `${MCPPOSH_API_KEY}` | depends on the client |

### Claude Desktop over HTTP

Claude Desktop does not read remote servers from its configuration file. Either add the server as a custom connector
in Claude Desktop (*Settings › Connectors*), or use the `mcp-remote` bridge that `Get-McpClientConfig` creates
(requires Node.js):

```json
{
  "mcpServers": {
    "mcpposh-contoso": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://mcpposh.example.com/mcp", "--header", "Authorization:${MCPPOSH_AUTH_HEADER}"],
      "env": { "MCPPOSH_AUTH_HEADER": "Bearer <your-api-key>" }
    }
  }
}
```

## Verify the connection

```powershell
Test-McpServer -KnowledgeBase Contoso -Query 'VPN'                  # what stdio clients start
Test-McpServer -Uri https://mcpposh.example.com -ApiKey $key        # HTTP servers
Get-McpServerLog -KnowledgeBase Contoso -Stdio -Tail 20             # shows "initialize from <client>"
```

If a client does not show the tools, see [Troubleshooting](troubleshooting.md#the-ai-client-does-not-show-the-tools).
