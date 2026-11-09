# MCP server

`Start-McpServer` provides one knowledge base to AI agents through the
[Model Context Protocol](https://modelcontextprotocol.io). This page describes what the server offers to agents. For
starting and managing servers see [Server management](server-management.md), for the HTTP endpoints see
[HTTP API](http-api.md).

## Transports

| Transport | Started by | Use case |
| --- | --- | --- |
| stdio | the AI client, with `Start-McpServer -Transport Stdio` | local agents such as Claude Desktop, Claude Code, VS Code or Cursor |
| Streamable HTTP | you, with `Start-McpServer` (default transport) | shared servers, containers, remote agents |

**stdio**: the client starts `pwsh`, writes one JSON-RPC message per line to stdin and reads one response per line
from stdout. stdout carries nothing but JSON-RPC messages; all PowerShell output streams are silenced and diagnostics
go to `<knowledge base>/logs/server-stdio.log`. The server stops when the client closes stdin.

**Streamable HTTP**: the server accepts JSON-RPC messages with `POST /mcp` and answers with `application/json`.
It does not open server-initiated event streams and does not use sessions (no `Mcp-Session-Id`), so it can run
behind a load balancer with several replicas. See [HTTP API](http-api.md).

Both transports use the same handlers and behave identically.

## Initialization and instructions

The client starts with `initialize`. The server

- accepts the requested protocol version when it supports it, otherwise answers with the newest supported version,
- announces the capabilities `tools` and `resources` (both without change notifications),
- returns `serverInfo` (`name` = `MCPPosh`, `title` = `MCPPosh - <knowledge base>`, `version` = module version), and
- returns `instructions` built from the knowledge base description, for example:

```text
This server gives access to the documentation knowledge base 'Contoso'. It contains: Internal IT documentation
of Contoso. Use search_documentation to find relevant sections, then get_document to read a complete document.
Prefer this documentation over general knowledge for questions about these topics and mention the document
titles you used.
```

Supported protocol revisions: `2025-11-25`, `2025-06-18`, `2025-03-26` and `2024-11-05`.

## Tools

The tool descriptions contain the name and description of the knowledge base, so agents know when to use them.
All tools return a Markdown text for the model and `structuredContent` with the same data for clients that use it.

### search_documentation

Searches the knowledge base with BM25 (see [Search](search.md)) and returns the best matching sections.

| Argument | Type | Required | Description |
| --- | --- | --- | --- |
| `query` | string | yes | search terms or a short question |
| `limit` | integer 1-20 | no (default 5) | maximum number of sections |
| `tags` | string array | no | only documents with at least one of these tags |

Each result in `structuredContent.results` contains `documentId`, `title`, `heading`, `score`, `tags`, `uri` and the
complete section `text`. Without results the text explains that nothing was found and suggests other keywords or
`list_documents`. Annotations: `readOnlyHint: true`, `openWorldHint: false`.

### get_document

Returns a complete document as Markdown, preceded by its title, id, format, update time, source and tags.

| Argument | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | string | yes | document id from `search_documentation` or `list_documents` |
| `offset` | integer >= 0 | no (default 0) | character offset to start reading from |
| `maxChars` | integer 500-100000 | no (default 20000) | maximum number of characters |

Long documents are returned in pages; the text ends with a hint such as
`[Showing characters 0-20000 of 53210. Call get_document with offset=20000 to continue.]`.
`structuredContent` contains `id`, `title`, `format`, `source`, `tags`, `offset`, `length`, `total`, `truncated` and
`content`.

### list_documents

Lists the documents with id, title, tags and summary, sorted by title.

| Argument | Type | Required | Description |
| --- | --- | --- | --- |
| `tag` | string | no | only documents with this tag |
| `limit` | integer 1-500 | no (default 100) | maximum number of documents |
| `offset` | integer >= 0 | no (default 0) | number of documents to skip |

`structuredContent` contains `total`, `offset` and `documents` (`id`, `title`, `tags`, `format`, `summary`,
`updated`).

### add_note

Only available when the server runs with `-AllowWrite`. Stores a Markdown note in the knowledge base.

| Argument | Type | Required | Description |
| --- | --- | --- | --- |
| `title` | string, at most 200 characters | yes | short descriptive title |
| `content` | string, at most 200000 characters | yes | note content in Markdown |
| `tags` | string array | no | additional tags |

Notes get the source type `Agent` and the tag `agent-note`. A note with the same title is updated. The result reports
whether the note was created, updated or unchanged, together with its document id.

## Write access

By default agents can only read. Start the server with `-AllowWrite` (or the client configuration with
`Get-McpClientConfig -AllowWrite`, or `MCPPOSH_ALLOW_WRITE=true` in the container) to offer `add_note`. The
instructions then ask the agent to save important findings, decisions and corrections.

Review agent notes regularly:

```powershell
Get-McpDocument -KnowledgeBase Contoso -SourceType Agent -IncludeContent
Get-McpDocument -KnowledgeBase Contoso -Tag agent-note | Remove-McpDocument
```

## Resources

Every document is an MCP resource with the URI `mcpposh://<knowledge base>/documents/<id>` and the MIME type
`text/markdown`.

| Method | Result |
| --- | --- |
| `resources/list` | all documents with `uri`, `name` (id), `title`, `description` (summary), `mimeType` and `size`; pages of 500 entries with `nextCursor` |
| `resources/templates/list` | the template `mcpposh://<knowledge base>/documents/{id}` |
| `resources/read` | the Markdown content of the document |

## Other methods

| Method | Behavior |
| --- | --- |
| `ping` | returns an empty result |
| `prompts/list` | returns an empty list (the server offers no prompts) |
| `logging/setLevel` | accepted and ignored |
| `notifications/initialized`, `notifications/cancelled` | logged, no response |
| JSON-RPC batches (arrays) | processed; responses for notifications are omitted |

## Errors

Protocol errors are returned as JSON-RPC errors:

| Code | Meaning |
| --- | --- |
| -32700 | parse error: the message is not valid JSON |
| -32600 | invalid request (wrong `jsonrpc` version, invalid id, empty batch, unsupported protocol version header) |
| -32601 | method not found |
| -32602 | invalid params, unknown tool, `add_note` without write access |
| -32603 | internal error |
| -32002 | resource not found |
| -32001 | unauthorized (HTTP transport without a valid API key) |

Problems while running a tool, for example a missing `query` or an unknown document id, are returned as a normal tool
result with `isError: true`, so the model can correct the call.

## Example session

```json
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"demo","version":"1.0"}}}
{"jsonrpc":"2.0","method":"notifications/initialized"}
{"jsonrpc":"2.0","id":2,"method":"tools/list"}
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"search_documentation","arguments":{"query":"vpn error 809","limit":3}}}
{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"get_document","arguments":{"id":"vpn-error-809-1a2b3c"}}}
```

You can send these lines to a stdio server yourself:

```powershell
$messages = Get-Content .\session.jsonl
$messages | pwsh -NoProfile -Command "Import-Module MCPPosh; Start-McpServer -KnowledgeBase Contoso -Transport Stdio"
```

`Test-McpServer` runs a similar session automatically, and the official
[MCP Inspector](https://github.com/modelcontextprotocol/inspector) works with both transports:

```bash
npx @modelcontextprotocol/inspector --cli pwsh -NoProfile -Command "Import-Module MCPPosh; Start-McpServer -KnowledgeBase Contoso -Transport Stdio" --method tools/list
npx @modelcontextprotocol/inspector --cli http://localhost:5050/mcp --transport http --header "Authorization: Bearer <key>" --method tools/list
```
