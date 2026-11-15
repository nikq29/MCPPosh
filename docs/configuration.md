# Configuration reference

PSMcpKnowledgeBase is configured with cmdlet parameters and a few environment variables. Everything else is stored in plain
JSON and Markdown files.

## Environment variables

| Variable | Used by | Meaning |
| --- | --- | --- |
| `PSMCPKB_HOME` | all cmdlets | data directory; default `~/.psmcpkb` (in the container `/data`) |
| `PSMCPKB_API_KEY` | `Start-McpServer`, `Restart-McpServer` | comma-separated API keys used when `-ApiKey` is not specified |

Additional variables of the container image (`PSMCPKB_KNOWLEDGEBASE`, `PSMCPKB_DESCRIPTION`, `PSMCPKB_PORT`,
`PSMCPKB_ALLOW_WRITE`, `PSMCPKB_ALLOW_ANONYMOUS`, `PSMCPKB_ALLOWED_ORIGINS`, `PSMCPKB_IMPORT_PATH`) are described in
[Docker](hosting-docker.md#environment-variables).

## Data directory

```text
$env:PSMCPKB_HOME (default ~/.psmcpkb)
├── knowledgebases/
│   └── <name>/
│       ├── knowledgebase.json
│       ├── manifest.json
│       ├── documents/<id>.md
│       ├── index/<id>.json
│       ├── logs/
│       ├── .lock
│       └── .publish/<account>-<share>-<name>.json
└── servers/
    └── <knowledge base>-<port>.json
```

All files are UTF-8 without byte order mark and are written atomically.

### knowledgebase.json

| Field | Meaning |
| --- | --- |
| `schemaVersion` | format version, currently `1` |
| `name` | name of the knowledge base |
| `description` | description sent to agents as instructions |
| `created` | creation time (UTC, ISO 8601) |

### manifest.json

| Field | Meaning |
| --- | --- |
| `schemaVersion` | format version, currently `1` |
| `revision` | increases with every change |
| `updated` | time of the last change |
| `documents` | one record per document |

Document record:

| Field | Meaning |
| --- | --- |
| `id` | document id, for example `installation-guide-3f9a1c` |
| `title` | title |
| `format` | converter that produced the content (`Markdown`, `Html`, `Docx`, `Pdf`, `Csv`, `Json`, `Yaml`, `Xml`, `Code`, `Text` or a custom converter) |
| `sourceType` | `File`, `Url`, `Inline`, `Agent` or `Imported` (file and URL documents from an archive imported without `-TrustSource`) |
| `source` | full file path or URL, empty for inline documents and agent notes |
| `tags` | tags |
| `hash` | SHA-256 of the normalized content |
| `sourceHash` | SHA-256 of the source file at the last import |
| `chars` | length of the content |
| `summary` | first paragraph, at most 200 characters |
| `added`, `updated` | timestamps (UTC, ISO 8601) |

### index/&lt;id&gt;.json

Contains `schemaVersion`, `id` and `chunks`. Each chunk has `heading` (heading path), `text`, `len` (number of weighted
terms) and `tf` (term frequencies). Index files are rebuilt automatically when they are missing or damaged.

### servers/&lt;knowledge base&gt;-&lt;port&gt;.json

Written by running HTTP servers and removed when they stop: `pid`, `processStartTime`, `knowledgeBase`, `kbPath`,
`transport`, `port`, `listenAddress`, `url`, `allowWrite`, `authRequired`, `allowAnonymous`, `allowedOrigins`,
`logFile`, `startedAt` and `version`. API keys are never written.

### .publish/

Stores the SHA-256 hashes of the files uploaded by `Publish-McpKnowledgeBase` per storage account, share and remote
name, so only changed files are uploaded the next time.

## Defaults and limits

| Setting | Value |
| --- | --- |
| HTTP port | 5050 (container: 8080) |
| Listen address | `localhost` |
| Background server start timeout | 30 seconds (`-StartTimeoutSeconds`) |
| Knowledge base lock timeout | 30 seconds |
| Index reload check of running servers | at most once per second |
| Chunk size | 1500 characters |
| Search results | 5 by default, 1-20 for `search_documentation`, 1-100 for `Search-McpDocument` |
| Sections per document in a result | 3 |
| Snippet length | 240 characters |
| `get_document` page size | 20000 characters by default, 500-100000 |
| `list_documents` page size | 100 by default, 1-500 |
| `resources/list` page size | 500 |
| `add_note` | title at most 200, content at most 200000 characters |
| Agent notes (`add_note`) | at most 1000 notes and 10 million characters per knowledge base, 30 notes per minute per server |
| HTTP request body | at most 10 MB, `Content-Type: application/json`, complete within 30 seconds |
| JSON-RPC batch | at most 100 messages |
| `Import-McpKnowledgeBase` | at most 100000 archive entries and 1 GB uncompressed content |
| Word (.docx) import | at most 64 MB per decompressed part, no document type definitions (DTDs) |
| URL import (`-Url`) | at most 100 MB per download |
| URL import | at most 5 redirects, `http` and `https` only |
| Stop words | English and German |

## PowerShell preferences

PSMcpKnowledgeBase cmdlets support the common parameters. Use `-Verbose` to see which documents were added, updated or
unchanged, and `-WhatIf`/`-Confirm` with all cmdlets that change data.
