# MCPPosh

**Serve your own documentation to AI agents through an MCP server, managed entirely from PowerShell.**

MCPPosh is a PowerShell module that builds a knowledge base from your documents (Markdown, Word,
PDF, HTML and web pages, CSV, JSON/YAML/XML, source code ...) and provides it to AI agents such as
Claude Desktop, Claude Code, GitHub Copilot in VS Code or Cursor through the
[Model Context Protocol](https://modelcontextprotocol.io). The server runs locally or centrally,
for example in Azure.

```powershell
Install-PSResource -Name MCPPosh
New-McpKnowledgeBase -Name Contoso -Description 'Internal IT documentation: runbooks, architecture, FAQ'
Add-McpDocument -KnowledgeBase Contoso -Path .\docs -Recurse
Get-McpClientConfig -KnowledgeBase Contoso -Client ClaudeDesktop   # configuration for the agent
```

## Features

- **Add knowledge in many formats**: files, whole folders, pipeline input from `Get-ChildItem`,
  web pages (`-Url`) and text (`-Content`). Add your own formats with `Register-McpDocumentConverter`.
- **Local full-text search (BM25)**: section based, with light stemming for English and German,
  prefix expansion and tag filters. No API keys, no cloud dependency.
- **MCP server with two transports**: *stdio* (the agent starts the server) and *Streamable HTTP*
  (background process or container) protected by API keys.
- **Managed from PowerShell**: start, stop, restart, status, logs, end-to-end tests and
  ready-to-use client configurations.
- **Live reload**: documents you add are available immediately, also on running servers.
- **Optional write access**: with `-AllowWrite` the agent can store knowledge itself through `add_note`.
- **Central hosting**: Docker image (installs MCPPosh from the PowerShell Gallery), Bicep template
  for Azure Container Apps with Azure Files and `Publish-McpKnowledgeBase` for publishing.

## Requirements

- **PowerShell 7.2 or later** on Windows, Linux or macOS. Windows PowerShell 5.1 is not supported.
- Optional for PDF: the module [PSWritePDF](https://www.powershellgallery.com/packages/PSWritePDF)
  or `pdftotext` (Poppler), see [PDF support](#pdf-support).
- Optional for Azure: `Az.Storage` (publishing), `Az.Resources` and the Bicep CLI (deployment).

## Installation

From the PowerShell Gallery:

```powershell
Install-PSResource -Name MCPPosh            # PowerShell 7.4+ (PSResourceGet)
Install-Module -Name MCPPosh -Scope CurrentUser   # alternatively with PowerShellGet
```

From source (the module is built with [Sampler](https://github.com/gaelcolas/Sampler)):

```powershell
git clone https://github.com/nikq29/MCPPosh.git
cd MCPPosh
./build.ps1 -ResolveDependency -Tasks build
Import-Module ./output/module/MCPPosh
```

## Quick start

```powershell
# 1. Create a knowledge base. The description is sent to the agent as instructions.
New-McpKnowledgeBase -Name Contoso -Description 'Internal IT documentation of Contoso.'

# 2. Add knowledge
Add-McpDocument -KnowledgeBase Contoso -Path C:\Docs -Recurse -Tags internal
Add-McpDocument -KnowledgeBase Contoso -Url https://example.com/handbook.html
Add-McpDocument -KnowledgeBase Contoso -Title 'VPN error 809' -Content 'Check the firewall rule VPN-IKE.' -Tags vpn

# 3. Test the search the way the agent searches
Search-McpDocument -KnowledgeBase Contoso -Query 'vpn connection drops'

# 4. Connect an agent (example: Claude Code)
(Get-McpClientConfig -KnowledgeBase Contoso -Client ClaudeCode).Command

# 5. Test end to end
Test-McpServer -KnowledgeBase Contoso -Query 'VPN'
```

## Adding knowledge

`Add-McpDocument` converts everything to Markdown when it is added and builds a search index.
Adding the same file or URL again updates the existing document instead of creating a duplicate;
text added with `-Content` is matched by its title.

| Format | Extensions | Notes |
| --- | --- | --- |
| Markdown | `.md` `.markdown` `.mdx` | title and tags from front matter (`title:`, `tags:`) |
| Text | `.txt` `.log` `.rst` `.adoc` ... | unknown text files are read as text |
| HTML / web | `.html` `.htm`, `-Url` | headings, lists, tables, code and links are kept; navigation and scripts are removed |
| Word | `.docx` | pure .NET, no Office required; headings (also localized), lists, tables |
| PDF | `.pdf` | through PSWritePDF or pdftotext |
| CSV / TSV | `.csv` `.tsv` | converted to a Markdown table, the delimiter (`,` `;` tab) is detected |
| JSON / YAML / XML | `.json` `.yaml` `.yml` `.xml` `.config` ... | as code block |
| Source code | `.ps1` `.py` `.cs` `.js` `.ts` `.sql` `.sh` `.bicep` `.tf` `Dockerfile` ... | as code block with language |

```powershell
Add-McpDocument -Path .\docs -Recurse -Include *.md, *.docx -Exclude *draft* -Tags handbook
Get-ChildItem \\server\wiki -Filter *.html -Recurse | Add-McpDocument -KnowledgeBase Contoso
Add-McpDocument -Url https://learn.microsoft.com/powershell/scripting/overview
Add-McpDocument -Path .\export.dat -Format Text      # force a converter
```

### Maintaining documents

```powershell
Get-McpDocument -KnowledgeBase Contoso -Tag runbook
Get-McpDocument -KnowledgeBase Contoso -Title '*VPN*' -IncludeContent
Set-McpDocument -KnowledgeBase Contoso -Id vpn-error-809-1a2b3c -AddTags network
Update-McpDocument -KnowledgeBase Contoso -All -RemoveMissing   # re-import changed sources
Get-McpDocument -KnowledgeBase Contoso -Tag obsolete | Remove-McpDocument
```

### Custom formats

```powershell
Register-McpDocumentConverter -Name Email -Extension .eml -ScriptBlock {
    param($Path)
    @{ Title = (Split-Path $Path -LeafBase); Content = Get-Content -LiteralPath $Path -Raw }
}
Get-McpDocumentConverter          # all formats and extensions
```

The script block returns a Markdown string or a hashtable with `Content`, `Title` and `Tags`.
Registrations last for the current session; put them in your profile to keep them. Running servers
do not need the converter because documents are converted when they are added.

### PDF support

PDFs are read with an additional tool. MCPPosh uses what is available:

1. **PSWritePDF** (PowerShell module, `Convert-PDFToText`): `Install-PSResource PSWritePDF`
2. **pdftotext** from Poppler: `winget install oschwartz10612.Poppler`, `brew install poppler` or `apt install poppler-utils`

> PSWritePDF bundles the iText 7 library, which is licensed under the AGPL. This matters if you
> redistribute it commercially.

After installing PDF support, `Update-McpDocument -All -Force` re-imports existing PDFs.

## Providing the server

### stdio: the agent starts the server

AI clients start `pwsh` with `Start-McpServer -Transport Stdio`. `Get-McpClientConfig` creates the
matching configuration:

```powershell
Get-McpClientConfig -KnowledgeBase Contoso -Client ClaudeDesktop     # claude_desktop_config.json
Get-McpClientConfig -KnowledgeBase Contoso -Client ClaudeCode        # .Command = 'claude mcp add ...'
Get-McpClientConfig -KnowledgeBase Contoso -Client VSCode -AsJson | Set-Content .vscode/mcp.json
Get-McpClientConfig -KnowledgeBase Contoso -Client Cursor            # ~/.cursor/mcp.json
```

Example output for Claude Desktop with MCPPosh installed from the Gallery:

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

### HTTP: server in the background

```powershell
Start-McpServer -KnowledgeBase Contoso -Port 5050 -ApiKey $key   # http://localhost:5050/mcp
Get-McpServer
Get-McpServerLog -KnowledgeBase Contoso -Port 5050 -Wait
Restart-McpServer -KnowledgeBase Contoso -ApiKey $key
Stop-McpServer -KnowledgeBase Contoso

Get-McpClientConfig -KnowledgeBase Contoso -Client VSCode -Transport Http -ApiKeyPlaceholder
```

- By default the server only listens on `localhost`. With `-ListenAddress '*'` it is reachable from
  the network and `-ApiKey` is required. On Windows this also needs administrator rights or a URL
  ACL (`netsh http add urlacl url=http://+:5050/ user=DOMAIN\user`).
- Clients send the API key as `Authorization: Bearer <key>` or `X-API-Key: <key>`. Several keys are
  possible, for example for key rotation. Alternatively set `$env:MCPPOSH_API_KEY`.
- `-Foreground` keeps the server in the current console (for containers and troubleshooting).

### What the agent gets

| MCP tool | Purpose |
| --- | --- |
| `search_documentation` | full-text search; returns the best matching sections with their document ids |
| `get_document` | a complete document as Markdown, paged for long documents (`offset`) |
| `list_documents` | documents with title, tags and summary (filter by tag) |
| `add_note` | store a note, only with `-AllowWrite` |

Every document is also available as MCP resource `mcpposh://<knowledge base>/documents/<id>`. The
description of the knowledge base is sent as `instructions`. Supported protocol revisions:
2025-11-25, 2025-06-18, 2025-03-26 and 2024-11-05.

## Central hosting (Docker / Azure)

The Docker image installs MCPPosh from the PowerShell Gallery:

```bash
docker build -f docker/Dockerfile --build-arg MCPPOSH_VERSION=0.1.0 -t mcpposh .
docker run -p 8080:8080 -e MCPPOSH_API_KEY=<key> -e MCPPOSH_KNOWLEDGEBASE=Contoso -v mcpposh-data:/data mcpposh
```

Released images are published as `ghcr.io/nikq29/mcpposh:<version>`. To test an unreleased build,
copy `output/MCPPosh.*.nupkg` to `docker/packages` and build with `--build-arg MCPPOSH_SOURCE=Local`.

[`deploy/azure`](deploy/azure/README.md) contains a Bicep template and `deploy.ps1` that deploy a
Container App with HTTPS and an API key; the knowledge base lives on Azure Files. You keep
maintaining the knowledge locally and publish it with PowerShell:

```powershell
./deploy/azure/deploy.ps1 -ResourceGroupName rg-mcpposh -Image ghcr.io/nikq29/mcpposh:latest -KnowledgeBase Contoso -Publish
Publish-McpKnowledgeBase -Name Contoso -StorageAccountName <storage> -ShareName mcpposh -ResourceGroupName rg-mcpposh -Prune
Get-McpServer  -Uri https://<app>.azurecontainerapps.io/mcp -ApiKey $key
Test-McpServer -Uri https://<app>.azurecontainerapps.io/mcp -ApiKey $key -Query 'VPN'
```

## Cmdlet overview

| Area | Cmdlets |
| --- | --- |
| Knowledge bases | `New-`, `Get-`, `Set-`, `Remove-McpKnowledgeBase`, `Export-`/`Import-McpKnowledgeBase` (ZIP), `Publish-McpKnowledgeBase` (Azure Files) |
| Documents | `Add-`, `Get-`, `Set-`, `Update-`, `Remove-McpDocument`, `Search-McpDocument` |
| Formats | `Register-`, `Get-`, `Unregister-McpDocumentConverter` |
| Server | `Start-`, `Stop-`, `Restart-`, `Get-McpServer`, `Test-McpServer`, `Get-McpServerLog` |
| Clients | `Get-McpClientConfig` |

Help for every cmdlet: `Get-Help Add-McpDocument -Full` and `Get-Help about_MCPPosh`. More examples
are in [`examples`](examples).

## Storage location and layout

Data is stored below `$env:MCPPOSH_HOME`, by default `~/.mcpposh`:

```
~/.mcpposh/
├── knowledgebases/<name>/
│   ├── knowledgebase.json   # name, description
│   ├── manifest.json        # document list, revision
│   ├── documents/<id>.md    # normalized content
│   ├── index/<id>.json      # precomputed search index (sections, term frequencies)
│   └── logs/                # server-stdio.log, server-<port>.log
└── servers/                 # state of locally started HTTP servers
```

Instead of a name, `-KnowledgeBase` also accepts a path, for example on a mounted network share.
The knowledge base `Default` is created automatically when it is first used.

## Security

- stdio servers run with the rights of the user who starts the agent.
- HTTP servers only listen on `localhost` by default and check the `Origin` header (protection
  against DNS rebinding). Other addresses require an API key, unless `-AllowAnonymous` is used
  behind an authenticating gateway.
- API keys are never stored and are passed to background processes through the environment, not
  on the command line. Keys are compared in constant time.
- Write access for the agent (`add_note`) is off by default. Agent notes are tagged `agent-note` and
  can be reviewed with `Get-McpDocument -SourceType Agent`.
- `-Url` only accepts `http` and `https`.

## Development

MCPPosh uses the [Sampler](https://github.com/gaelcolas/Sampler) build framework.

```powershell
./build.ps1 -ResolveDependency -Tasks noop   # download the build dependencies into output/RequiredModules
./build.ps1 -Tasks build                     # build the module into output/module/MCPPosh/<version>
./build.ps1 -Tasks test                      # QA, unit and integration tests with code coverage
./build.ps1 -Tasks pack                      # create output/MCPPosh.<version>.nupkg (requires the dotnet CLI)
```

- Sources are in `source/` with one function per file (`Public/` exported, `Private/` internal);
  `prefix.ps1` and `suffix.ps1` are merged into the built `MCPPosh.psm1`.
- Tests: `tests/QA` (Sampler quality checks: help, PSScriptAnalyzer and a unit test file for every
  function, changelog), `tests/Unit/Public` and `tests/Unit/Private` (one file per function) and
  `tests/Integration` (real stdio and HTTP server processes).
- Every change needs an entry in the `Unreleased` section of [CHANGELOG.md](CHANGELOG.md).

### Releases

The version is calculated by [GitVersion](https://gitversion.net) from the Git history
(`GitVersion.yml`). The workflow [`.github/workflows/build.yml`](.github/workflows/build.yml)
builds and tests every push and pull request on Windows, Linux and macOS. Pushing a tag `vX.Y.Z`
additionally

1. publishes the module to the PowerShell Gallery and creates a GitHub release (Sampler task `publish`),
2. builds the Docker image with that version from the Gallery and pushes it to `ghcr.io/<owner>/mcpposh`.

Publishing requires the repository secret `GALLERY_API_TOKEN` with a PowerShell Gallery API key.

## License

[MIT](LICENSE)
