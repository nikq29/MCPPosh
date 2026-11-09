---
Module Name: MCPPosh
Module Guid: a4c5aad7-b202-47f2-b38d-baca8f8a568f
Download Help Link: https://github.com/nikq29/MCPPosh/tree/main/docs/en-US
Help Version: 0.0.1
Locale: en-US
---

# MCPPosh Module
## Description
MCPPosh hosts a Model Context Protocol (MCP) server that serves your own documentation to AI agents and lets you manage the server and its knowledge base entirely from PowerShell. It imports Markdown, text, HTML and web pages, Word (.docx), PDF, CSV, JSON, YAML, XML and source code, ships a local BM25 search and supports the stdio and Streamable HTTP transports. See the [documentation](../README.md) for guides.

## MCPPosh Cmdlets
### [Add-McpDocument](Add-McpDocument.md)
Adds knowledge to a knowledge base: files, folders, web pages or inline text.

### [Export-McpKnowledgeBase](Export-McpKnowledgeBase.md)
Exports a knowledge base to a ZIP archive (backup or transfer to another machine).

### [Get-McpClientConfig](Get-McpClientConfig.md)
Generates the configuration to connect an AI client to an MCPPosh server.

### [Get-McpDocument](Get-McpDocument.md)
Lists the documents of a knowledge base.

### [Get-McpDocumentConverter](Get-McpDocumentConverter.md)
Lists the available document converters (formats) and their file extensions.

### [Get-McpKnowledgeBase](Get-McpKnowledgeBase.md)
Lists knowledge bases or gets a specific one.

### [Get-McpServer](Get-McpServer.md)
Shows MCPPosh HTTP servers: local background/foreground servers, or a remote server.

### [Get-McpServerLog](Get-McpServerLog.md)
Shows the log of an MCP server.

### [Import-McpKnowledgeBase](Import-McpKnowledgeBase.md)
Imports a knowledge base from a ZIP archive created by Export-McpKnowledgeBase.

### [New-McpKnowledgeBase](New-McpKnowledgeBase.md)
Creates a new knowledge base for documentation that an MCP server can serve.

### [Publish-McpKnowledgeBase](Publish-McpKnowledgeBase.md)
Publishes a local knowledge base to an Azure Files share used by a hosted MCPPosh server.

### [Register-McpDocumentConverter](Register-McpDocumentConverter.md)
Registers a custom converter so Add-McpDocument can import additional file formats.

### [Remove-McpDocument](Remove-McpDocument.md)
Removes documents from a knowledge base.

### [Remove-McpKnowledgeBase](Remove-McpKnowledgeBase.md)
Deletes a knowledge base including all of its documents.

### [Restart-McpServer](Restart-McpServer.md)
Restarts local MCPPosh HTTP servers with their previous settings.

### [Search-McpDocument](Search-McpDocument.md)
Searches a knowledge base with the same BM25 search the AI agent uses.

### [Set-McpDocument](Set-McpDocument.md)
Changes the title, tags or content of a document.

### [Set-McpKnowledgeBase](Set-McpKnowledgeBase.md)
Changes the description of a knowledge base.

### [Start-McpServer](Start-McpServer.md)
Starts an MCP server that provides a knowledge base to AI agents.

### [Stop-McpServer](Stop-McpServer.md)
Stops MCPPosh HTTP servers that run on this machine.

### [Test-McpServer](Test-McpServer.md)
Checks an MCP server end-to-end like an AI client would.

### [Unregister-McpDocumentConverter](Unregister-McpDocumentConverter.md)
Removes a custom document converter. Built-in converters cannot be removed.

### [Update-McpDocument](Update-McpDocument.md)
Re-imports file and URL documents from their original source when the source changed.
