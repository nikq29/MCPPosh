# Concepts and architecture

MCPPosh has three parts: knowledge bases that store your documentation, a search engine that finds the relevant
sections, and an MCP server that makes both available to AI agents. All of them are plain PowerShell 7 code without
external dependencies.

```text
  PowerShell session                         MCP server process                     AI client
 ┌────────────────────────┐   writes    ┌───────────────────────────┐  stdio  ┌─────────────────────┐
 │ Add-McpDocument        │──────────►  │ knowledge base folder     │ ◄─────► │ Claude, Copilot,    │
 │ Set-/Update-/Remove-   │             │  manifest.json            │   or    │ Cursor ...          │
 │ McpDocument            │             │  documents/*.md           │  HTTP   │                     │
 │ Search-McpDocument     │  reads      │  index/*.json             │         │ search_documentation│
 └────────────────────────┘ ◄────────── │ in-memory BM25 index      │         │ get_document ...    │
                                        └───────────────────────────┘         └─────────────────────┘
```

## Knowledge base

A knowledge base is a folder, by default `~/.mcpposh/knowledgebases/<name>`:

| Path | Content |
| --- | --- |
| `knowledgebase.json` | name, description (sent to agents as instructions), schema version, creation time |
| `manifest.json` | revision counter, last update and one record per document |
| `documents/<id>.md` | normalized Markdown content of each document |
| `index/<id>.json` | precomputed search chunks with term frequencies |
| `logs/` | logs of the servers that serve the knowledge base |
| `.lock` | lock file that serializes writers |
| `.publish/` | state of `Publish-McpKnowledgeBase` (which files were uploaded) |

Because a knowledge base is just a folder, you can copy it, put it on a network share or mount it into a container.
Every cmdlet with a `-KnowledgeBase` parameter accepts a name or a path.

## Documents

A document is created from a file, a URL, inline text (`-Content`) or by an agent (`add_note`). When it is added:

1. A converter turns the source into Markdown (see [Adding knowledge](adding-knowledge.md)).
2. The content is normalized: LF line endings, no byte order mark, no trailing whitespace, one final newline.
3. A SHA-256 hash of the normalized content detects whether a document actually changed.
4. The content is split into sections and indexed (see [Search](search.md)).
5. The manifest record is written with id, title, format, source type, source, tags, hashes, size, summary and
   timestamps.

Document ids combine a readable slug of the title with a random suffix, for example `installation-guide-3f9a1c`.

Documents are matched so that importing the same source again updates the existing document:

| Source type | Matched by |
| --- | --- |
| `File` | full path of the file |
| `Url` | absolute URL |
| `Inline` | title |
| `Agent` | title |

## Consistency and concurrency

The PowerShell session and a running server with write access may change the same knowledge base at the same time.
MCPPosh therefore

- holds an exclusive lock (`.lock`) while it updates the manifest,
- writes every file atomically (temporary file, then rename), and
- writes the content and index files first and the manifest last, so a reader never sees a manifest entry without its
  files.

## Live reload

Servers keep the search index in memory. Before handling a request they compare the timestamp and size of
`manifest.json` with the loaded index, at most once per second. When the manifest changed, the index and the
knowledge base description are reloaded. Documents you add, change or remove are therefore visible to agents within
about a second, without restarting the server. This also works when the knowledge base is updated on an Azure Files
share by `Publish-McpKnowledgeBase`.

## MCP server

The server speaks JSON-RPC 2.0 over one of two transports:

- **stdio**: the AI client starts `pwsh` with `Start-McpServer -Transport Stdio` and exchanges one JSON message per
  line over stdin and stdout.
- **Streamable HTTP**: a long-running server accepts JSON-RPC requests with `POST /mcp`. It runs as a hidden
  background process, in the foreground of a console or in a container.

Both transports share the same handlers and offer the tools `search_documentation`, `get_document`,
`list_documents` and optionally `add_note`, plus every document as an MCP resource. See [MCP server](mcp-server.md).

## Local server processes

Background HTTP servers write a state file to `~/.mcpposh/servers/<knowledge base>-<port>.json` with process id,
process start time, port, URL and options. `Get-McpServer`, `Stop-McpServer` and `Restart-McpServer` use these
files; the process start time protects against stopping an unrelated process that reused the process id.

## Module layout

The module is built with [Sampler](https://github.com/gaelcolas/Sampler). The sources in `source/` contain one function
per file; public functions in `source/Public` are exported, internal helpers live in `source/Private`. See
[Development](development.md).
