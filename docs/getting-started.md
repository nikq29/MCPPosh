# Getting started

This guide takes you from installation to an AI agent that answers questions from your own documentation.

## Requirements

- PowerShell 7.2 or later on Windows, Linux or macOS. Windows PowerShell 5.1 is not supported.
- An MCP-capable AI client, for example Claude Desktop, Claude Code, VS Code with GitHub Copilot or Cursor.
- Optional: [PSWritePDF](https://www.powershellgallery.com/packages/PSWritePDF) or `pdftotext` to import PDF files
  (see [Adding knowledge](adding-knowledge.md#pdf-support)).

Check your PowerShell version:

```powershell
$PSVersionTable.PSVersion
```

## 1. Install MCPPosh

```powershell
Install-PSResource -Name MCPPosh                    # PowerShell 7.4 and later (PSResourceGet)
Install-Module -Name MCPPosh -Scope CurrentUser     # alternatively with PowerShellGet
Import-Module MCPPosh
Get-Command -Module MCPPosh
```

To build the module from source instead, see [Development](development.md).

## 2. Create a knowledge base

A knowledge base is a named collection of documents. Its description is sent to the agent as instructions, so
describe what the documentation covers and when the agent should use it.

```powershell
New-McpKnowledgeBase -Name Contoso -Description 'Internal IT documentation of Contoso: runbooks, architecture and FAQ.'
```

The knowledge base is stored in `~/.mcpposh/knowledgebases/Contoso`. Set `$env:MCPPOSH_HOME` to use another
location. A knowledge base named `Default` is created automatically when a cmdlet uses it for the first time.

## 3. Add knowledge

```powershell
# A folder with Markdown, Word, HTML, PDF, CSV, JSON, YAML or script files
Add-McpDocument -KnowledgeBase Contoso -Path C:\Docs -Recurse -Tags internal

# A web page
Add-McpDocument -KnowledgeBase Contoso -Url https://example.com/handbook.html

# A short note
Add-McpDocument -KnowledgeBase Contoso -Title 'VPN error 809' -Content 'Check the firewall rule VPN-IKE.' -Tags vpn
```

Every document is converted to Markdown and indexed for the search. See [Adding knowledge](adding-knowledge.md) for
all formats and options.

## 4. Check what the agent will find

`Search-McpDocument` runs exactly the search that the agent's `search_documentation` tool uses:

```powershell
Search-McpDocument -KnowledgeBase Contoso -Query 'vpn connection drops' | Format-List Score, Title, Heading, Snippet
```

## 5. Connect an AI client

Most clients start the server themselves over stdio. `Get-McpClientConfig` creates the configuration:

```powershell
# Claude Code: run the returned command
(Get-McpClientConfig -KnowledgeBase Contoso -Client ClaudeCode).Command

# Claude Desktop: paste the JSON into the file shown in ConfigFile and restart Claude Desktop
Get-McpClientConfig -KnowledgeBase Contoso -Client ClaudeDesktop | Format-List ConfigFile, Json

# VS Code: write .vscode/mcp.json in your project
Get-McpClientConfig -KnowledgeBase Contoso -Client VSCode -AsJson | Set-Content .vscode/mcp.json
```

See [Client configuration](client-configuration.md) for all clients and for HTTP servers.

## 6. Test end to end

`Test-McpServer` starts the server like an AI client, performs the MCP handshake, lists the tools and runs a search:

```powershell
Test-McpServer -KnowledgeBase Contoso -Query 'VPN'
```

Now ask your agent a question about your documentation, for example "How do I fix VPN error 809?". The agent calls
`search_documentation`, reads the relevant sections and answers with the document titles it used.

## Next steps

- Keep the knowledge base up to date with `Update-McpDocument -All` ([Adding knowledge](adding-knowledge.md)).
- Run a shared HTTP server in the background ([Server management](server-management.md)).
- Host the server centrally in Docker or Azure ([Docker](hosting-docker.md), [Azure](hosting-azure.md)).
- Let agents store notes with `-AllowWrite` ([MCP server](mcp-server.md#write-access)).
