# Security

MCPPosh gives AI agents read access (and optionally write access) to your documentation. This page explains the
security model and recommendations.

## What agents can access

- An MCPPosh server provides exactly one knowledge base. Agents can search and read all of its documents, nothing
  else: no files outside the knowledge base, no commands, no other knowledge bases. Document ids are file names and
  may only contain letters, digits, `_` and `-`; documents with other ids in `manifest.json` (for example from a
  manipulated archive or share) are ignored, so they can never address files outside the knowledge base.
- Put only documentation into a knowledge base that every user of the connected agents may read. Use separate
  knowledge bases (and servers) for different audiences.
- Content of documents is passed to the language model. Do not import secrets such as passwords or API keys.
- Documents can contain text that tries to instruct the model (prompt injection), especially content imported from
  the web. Import web pages only from sources you trust.

## stdio servers

stdio servers are started by the AI client with the rights of the current user and only talk to that client through
stdin and stdout. They do not open network ports.

## HTTP servers

- **Loopback by default**: servers listen on `localhost` unless `-ListenAddress` says otherwise. A loopback server
  without API key can be used by every local user and process of the machine; set `-ApiKey` on shared machines.
- **API keys required on the network**: listening on any other address requires API keys. `-AllowAnonymous`
  disables this check and must only be used behind a gateway that authenticates every request (for example Azure
  Container Apps authentication or API Management).
- **Key handling**: keys are accepted as `Authorization: Bearer <key>` or `X-API-Key`, compared in constant time,
  never written to disk or to logs, and passed to background processes through the environment instead of the
  command line. Use long random keys, for example:

  ```powershell
  $bytes = [byte[]]::new(32); [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
  $key = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
  ```

- **Key rotation**: configure several keys (`-ApiKey old, new` or `MCPPOSH_API_KEY=old,new`), switch the clients,
  then remove the old key.
- **DNS rebinding protection**: loopback servers reject browser requests from non-local origins. Allow specific
  browser applications with `-AllowedOrigin`.
- **Cross-site requests**: `POST /mcp` only accepts `Content-Type: application/json`, which browsers never send
  cross-site without a CORS preflight. Servers started with `-AllowAnonymous` on a network address reject all browser
  origins that are not listed with `-AllowedOrigin`, because a gateway may authenticate with cookies.
- **No TLS**: the server speaks plain HTTP. Use HTTPS through a reverse proxy or a platform ingress (the Azure
  template does this) whenever traffic leaves the machine.
- **Health endpoint**: `/health` only reports `status`, `server` and `version` without a key.
- **Request size**: request bodies are limited to 10 MB, counted while reading (also for chunked requests), and
  batches to 100 messages.
- **Error details**: internal errors are reported to clients without details; exception messages (which can contain
  file paths) are only written to the server log. Client input is written to the log with line breaks and control
  characters escaped, so clients cannot forge log lines.

## Write access

`add_note` is only offered when the server runs with `-AllowWrite`. Agent notes are stored with the source type
`Agent` and the tag `agent-note`, can only add or update notes (never change or delete other documents) and are
limited to 200000 characters. Review them regularly with `Get-McpDocument -SourceType Agent`.

Notes written by one agent are served to every agent that uses the knowledge base later. An agent that processed
untrusted content can therefore store instructions that later agents read (stored prompt injection). Enable
`-AllowWrite` only for agents and users you trust, and review agent notes before you rely on them.

## Imports

- `-Url` only accepts `http` and `https` URLs and follows at most five redirects.
- `Import-McpKnowledgeBase` only extracts the expected knowledge base files from an archive and rejects entries that
  would be written outside the target folder, documents with invalid ids, more than 100000 entries and more than 1 GB
  of uncompressed content (counted while extracting, so decompression bombs are stopped).
- Word documents are read with a limit of 64 MB per decompressed part.
- Custom converters (`Register-McpDocumentConverter`) run arbitrary PowerShell code in your session; only register
  converters you trust.
- PDF extraction runs PSWritePDF or `pdftotext` on the imported files.

## Data at rest

Knowledge bases are plain files below `$env:MCPPOSH_HOME`. Protect the folder with file system permissions, and use
encrypted storage (for example Azure Files with encryption at rest, which is the default) for sensitive content.
Logs contain search queries and client names but no API keys and no document content.

## Reporting vulnerabilities

See [SECURITY.md](../SECURITY.md).
