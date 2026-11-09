# Changelog for MCPPosh

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Knowledge base management: `New-`, `Get-`, `Set-`, `Remove-McpKnowledgeBase`.
- Backup and transfer of knowledge bases as ZIP archives: `Export-McpKnowledgeBase`, `Import-McpKnowledgeBase`.
- Incremental publishing of a knowledge base to Azure Files: `Publish-McpKnowledgeBase`.
- Document management: `Add-`, `Get-`, `Set-`, `Update-`, `Remove-McpDocument`.
- Import of Markdown, text, HTML and web pages, Word (.docx), PDF (via PSWritePDF or pdftotext),
  CSV/TSV, JSON, YAML, XML and source code; custom formats with `Register-McpDocumentConverter`.
- Local BM25 search with heading-aware chunking, light German/English stemming, prefix expansion
  and tag filters: `Search-McpDocument`.
- MCP server over stdio and Streamable HTTP with the tools `search_documentation`, `get_document`,
  `list_documents` and the opt-in tool `add_note`; documents are exposed as MCP resources.
- Server management: `Start-`, `Stop-`, `Restart-`, `Get-McpServer`, `Test-McpServer`, `Get-McpServerLog`.
- Client configuration for Claude Desktop, Claude Code, VS Code and Cursor: `Get-McpClientConfig`.
- Docker image and Azure Container Apps deployment (Bicep) for central hosting.
- Sampler-based build, test and release pipeline with publishing to the PowerShell Gallery.
