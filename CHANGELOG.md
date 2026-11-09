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
- Complete English documentation in `docs/`: getting started, concepts, knowledge bases, adding knowledge,
  search, MCP server, server management, client configuration, HTTP API, Docker and Azure hosting,
  configuration reference, security, troubleshooting and development.
- Cmdlet reference in `docs/en-US`, generated from the comment-based help by the new Sampler build
  workflow `docs` (PlatyPS); `Get-Help <cmdlet> -Online` opens the reference page.
- Documentation quality tests (`tests/QA/docs.tests.ps1`) and Markdown linting in the CI workflow.
- `Publish-McpKnowledgeBase` returns `MCPPosh.PublishResult` objects.
- End-to-end integration tests for every cmdlet, parameter set and parameter in `tests/Integration`: all built-in
  formats, URL import from a local web server, generated client configurations started as real processes, foreground
  and background servers, and publishing to a local stand-in for Azure Files that a server then serves.
- QA test `tests/QA/integration.tests.ps1` that fails when a cmdlet, parameter set or parameter has no integration
  test, or when an integration test uses `Mock`.

### Fixed

- Markdown tables, search chunks and the text of the MCP tool results use LF line endings on every platform;
  on Windows they contained CRLF. Documents with CRLF line endings are chunked without carriage returns.
- The `Publish-McpKnowledgeBase` unit tests no longer fail when the Az.Storage module is installed.
