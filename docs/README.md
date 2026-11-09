# MCPPosh documentation

MCPPosh is a PowerShell module that serves your own documentation to AI agents through a
[Model Context Protocol](https://modelcontextprotocol.io) (MCP) server. You build and maintain the knowledge base with
PowerShell, and the server makes it searchable for agents such as Claude Desktop, Claude Code, GitHub Copilot in
VS Code or Cursor.

## Guides

| Guide | Content |
| --- | --- |
| [Getting started](getting-started.md) | Install the module, create a knowledge base, connect an agent |
| [Concepts and architecture](concepts.md) | How knowledge bases, documents, the search index and the server work together |
| [Knowledge bases](knowledge-bases.md) | Create, list, change, remove, back up, import and publish knowledge bases |
| [Adding knowledge](adding-knowledge.md) | Files, folders, web pages and text; all formats; PDF support; custom converters; maintenance |
| [Search](search.md) | Chunking, tokenization, stemming, BM25 ranking and tips for good results |
| [MCP server](mcp-server.md) | Transports, tools, resources, instructions, protocol versions and errors |
| [Server management](server-management.md) | Start, stop, restart, status, logs and end-to-end tests |
| [Client configuration](client-configuration.md) | Claude Desktop, Claude Code, VS Code, Cursor and other clients |
| [HTTP API](http-api.md) | Endpoints, authentication, status codes, CORS and examples with curl |
| [Docker](hosting-docker.md) | Container image, build arguments, environment variables and volumes |
| [Azure](hosting-azure.md) | Azure Container Apps with Azure Files, deployment and publishing |
| [Configuration reference](configuration.md) | Environment variables, files and default values |
| [Security](security.md) | Authentication, network exposure, write access and data handling |
| [Troubleshooting](troubleshooting.md) | Common problems and how to solve them |
| [Development](development.md) | Sampler build, tests, documentation, CI and releases |

## Cmdlet reference

The [cmdlet reference](en-US/MCPPosh.md) is generated from the comment-based help of the module with the Sampler
documentation task. The same help is available in PowerShell:

```powershell
Get-Command -Module MCPPosh
Get-Help Add-McpDocument -Full
Get-Help Add-McpDocument -Online   # opens the reference page on GitHub
Get-Help about_MCPPosh
```

| Area | Cmdlets |
| --- | --- |
| Knowledge bases | [New-McpKnowledgeBase](en-US/New-McpKnowledgeBase.md), [Get-McpKnowledgeBase](en-US/Get-McpKnowledgeBase.md), [Set-McpKnowledgeBase](en-US/Set-McpKnowledgeBase.md), [Remove-McpKnowledgeBase](en-US/Remove-McpKnowledgeBase.md), [Export-McpKnowledgeBase](en-US/Export-McpKnowledgeBase.md), [Import-McpKnowledgeBase](en-US/Import-McpKnowledgeBase.md), [Publish-McpKnowledgeBase](en-US/Publish-McpKnowledgeBase.md) |
| Documents | [Add-McpDocument](en-US/Add-McpDocument.md), [Get-McpDocument](en-US/Get-McpDocument.md), [Set-McpDocument](en-US/Set-McpDocument.md), [Update-McpDocument](en-US/Update-McpDocument.md), [Remove-McpDocument](en-US/Remove-McpDocument.md), [Search-McpDocument](en-US/Search-McpDocument.md) |
| Formats | [Register-McpDocumentConverter](en-US/Register-McpDocumentConverter.md), [Get-McpDocumentConverter](en-US/Get-McpDocumentConverter.md), [Unregister-McpDocumentConverter](en-US/Unregister-McpDocumentConverter.md) |
| Server | [Start-McpServer](en-US/Start-McpServer.md), [Stop-McpServer](en-US/Stop-McpServer.md), [Restart-McpServer](en-US/Restart-McpServer.md), [Get-McpServer](en-US/Get-McpServer.md), [Test-McpServer](en-US/Test-McpServer.md), [Get-McpServerLog](en-US/Get-McpServerLog.md) |
| Clients | [Get-McpClientConfig](en-US/Get-McpClientConfig.md) |

## Examples

The [examples](../examples) folder contains complete scripts:

- [01-Build-KnowledgeBase.ps1](../examples/01-Build-KnowledgeBase.ps1): create and fill a knowledge base
- [02-Connect-Agent.ps1](../examples/02-Connect-Agent.ps1): connect AI clients and manage a server
- [03-Azure-Hosting.ps1](../examples/03-Azure-Hosting.ps1): host the server in Azure and publish knowledge
