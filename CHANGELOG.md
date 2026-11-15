# Changelog for PSMcpKnowledgeBase

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
- `Publish-McpKnowledgeBase` returns `PSMcpKnowledgeBase.PublishResult` objects.
- End-to-end integration tests for every cmdlet, parameter set and parameter in `tests/Integration`: all built-in
  formats, URL import from a local web server, generated client configurations started as real processes, foreground
  and background servers, and publishing to a local stand-in for Azure Files that a server then serves.
- QA test `tests/QA/integration.tests.ps1` that fails when a cmdlet, parameter set or parameter has no integration
  test, or when an integration test uses `Mock`.
- OAuth sign-in for HTTP servers: `Start-McpServer -OAuthIssuer -OAuthAudience -OAuthScope` (or
  `PSMCPKB_OAUTH_ISSUER`, `PSMCPKB_OAUTH_AUDIENCE`, `PSMCPKB_OAUTH_SCOPE`) accepts JWT access tokens of an OpenID
  Connect identity provider such as Microsoft Entra ID next to API keys and publishes
  `/.well-known/oauth-protected-resource` so MCP clients can sign in. `Restart-McpServer` keeps the OAuth settings.
  The issuer must use https (http only for localhost), tokens need a scope or app roles (ID tokens are rejected), and
  the signing keys are refreshed daily.
- Azure template: `oauthClientId`/`oauthScope` enable Entra ID sign-in for the tenant of the deployment, and
  `allowAnonymous` is now available; `apiKey` is optional when one of them is used. The Deploy to Azure button opens a
  portal form (`createUiDefinition.json`) that lists the app registrations you own. `deploy.ps1` has
  `-OAuthClientId`, `-OAuthScope`, `-AllowAnonymous` and `-AllowedOrigin`.
- "Deploy to Azure" button for the Bicep template (`deploy/azure/azuredeploy.json`, checked against `main.bicep`
  in CI); the template parameter `image` defaults to `ghcr.io/nikq29/psmcpkb:latest`.

### Fixed

- Markdown tables, search chunks and the text of the MCP tool results use LF line endings on every platform;
  on Windows they contained CRLF. Documents with CRLF line endings are chunked without carriage returns.
- The `Publish-McpKnowledgeBase` unit tests no longer fail when the Az.Storage module is installed.
- `Publish-McpKnowledgeBase` stops when the share holds documents that do not exist locally and were not published
  from this computer, for example notes that agents saved with `add_note`. Before, it uploaded the local manifest
  and removed those notes from the server (and deleted their files with `-Prune`). `-Force` replaces them.

### Security

- `Import-McpKnowledgeBase` imports documents that were added from files or URLs with the new source type
  `Imported`, which `Update-McpDocument` skips. Before, an archive could name any local file (for example
  `~/.ssh/id_rsa`) or internal URL as the source of a document, and the next `Update-McpDocument -All` copied it
  into the knowledge base, where every connected agent could read it. The new switch `-TrustSource` keeps the
  sources for archives you created yourself. `Update-McpDocument` only reads sources whose type is exactly `File`
  or `Url`, so differently cased or non-string types in a manipulated manifest are skipped.
- Document ids from `manifest.json` are validated before they are used as file names. A manipulated manifest (from
  an imported archive or a shared folder) could make a server return, write or delete `.md` and `.json` files
  outside the knowledge base. `Import-McpKnowledgeBase` rejects such archives, and documents with invalid ids are
  ignored by the search index and never turned into paths.
- `Import-McpKnowledgeBase` rejects archives with more than 100000 entries or more than 1 GB of uncompressed content,
  counted while extracting; Word documents are read with a limit of 64 MB per decompressed part.
- The HTTP transport counts the request body while reading, so the 10 MB limit also applies to chunked requests;
  batches are limited to 100 messages.
- A request body that does not arrive completely within 30 seconds is answered with `408` and the connection is
  closed. Before, one client that stopped sending in the middle of a request blocked the server for everyone.
- `search_documentation` rejects queries longer than 1000 characters. Every unknown word is compared with the whole
  vocabulary, so one huge query could block the server for everyone for a long time.
- `add_note` accepts at most 20 tags of at most 50 characters. Tags are stored in the manifest and were not counted
  by the limits on agent notes.
- `add_note` is limited to 1000 agent notes and 10 million characters of agent notes per knowledge base and to
  30 notes per minute per server, so an agent cannot fill the disk or keep the server busy rebuilding the index.
- API keys are compared as SHA-256 hashes in constant time; before, the response time revealed the key length.
- Without a valid API key, `/health` no longer reports the version and the root page `/` no longer names the
  knowledge base.
- The XML of Word documents is parsed without document type definitions; documents that contain one are rejected
  (entity expansion).
- `Add-McpDocument -Url` and `Update-McpDocument` reject downloads larger than 100 MB before converting them.
- The `claude mcp add` command from `Get-McpClientConfig` quotes the server name and the URL, and uses PowerShell
  quoting on Windows; before, a `$` or backtick in a knowledge base path was expanded when the command was pasted
  into PowerShell.
- `POST /mcp` requires `Content-Type: application/json` (`415` otherwise), and servers started with
  `-AllowAnonymous` on a network address reject browser origins that are not listed with `-AllowedOrigin`.
- Internal errors and unexpected tool failures are reported to clients without exception details; the details are
  only written to the server log. Line breaks and control characters in logged client input are escaped.
- `Stop-McpServer` no longer stops a process whose identity cannot be confirmed (missing or unreadable start time
  of a non-PowerShell process).
- The Docker image verifies the SHA-256 checksum of the PowerShell archive, and the GitHub Actions in the workflow
  are pinned to commit SHAs (kept up to date by Dependabot).
