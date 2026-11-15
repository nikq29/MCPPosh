# Security

PSMcpKnowledgeBase gives AI agents read access (and optionally write access) to your documentation. This page explains the
security model and recommendations.

## What agents can access

- A PSMcpKnowledgeBase server provides exactly one knowledge base. Agents can search and read all of its documents, nothing
  else: no files outside the knowledge base, no commands, no other knowledge bases. Document ids are file names and
  may only contain letters, digits, `_` and `-`; documents with other ids in `manifest.json` (for example from a
  manipulated archive or share) are ignored, so they can never address files outside the knowledge base.
  The sources of file and URL documents are only read again by `Update-McpDocument`, never by the server (see
  [Imports](#imports)).
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

- **Key rotation**: configure several keys (`-ApiKey old, new` or `PSMCPKB_API_KEY=old,new`), switch the clients,
  then remove the old key.
- **DNS rebinding protection**: loopback servers reject browser requests from non-local origins. Allow specific
  browser applications with `-AllowedOrigin`.
- **Cross-site requests**: `POST /mcp` only accepts `Content-Type: application/json`, which browsers never send
  cross-site without a CORS preflight. Servers started with `-AllowAnonymous` on a network address reject all browser
  origins that are not listed with `-AllowedOrigin`, because a gateway may authenticate with cookies.
- **No TLS**: the server speaks plain HTTP. Use HTTPS through a reverse proxy or a platform ingress (the Azure
  template does this) whenever traffic leaves the machine.
- **Health endpoint**: without a key, `/health` only reports `status` and `server`, and the root page `/` does not
  name the knowledge base. The version and all details require the key, so they do not help an attacker.
- **API key comparison**: keys are compared as SHA-256 hashes in constant time, so response times reveal neither
  the key nor its length.
- **Request size**: request bodies are limited to 10 MB, counted while reading (also for chunked requests), and
  batches to 100 messages.
- **Slow clients**: the server handles one request at a time. A request body that does not arrive completely within
  30 seconds is answered with `408` and the connection is closed, so a stalled or malicious client cannot block the
  server for others.
- **Error details**: internal errors are reported to clients without details; exception messages (which can contain
  file paths) are only written to the server log. Client input is written to the log with line breaks and control
  characters escaped, so clients cannot forge log lines.

## Write access

`add_note` is only offered when the server runs with `-AllowWrite`. Agent notes are stored with the source type
`Agent` and the tag `agent-note`, can only add or update notes (never change or delete other documents) and are
limited to 200000 characters and 20 tags of at most 50 characters. Review them regularly with
`Get-McpDocument -SourceType Agent`.

To keep an agent from filling the disk or keeping the server busy, a knowledge base holds at most 1000 agent notes
with at most 10 million characters in total, and a server accepts at most 30 notes per minute. Updating a note with
the same title is still possible when the limits are reached. Documents added by people do not count. When a limit
is reached, `add_note` returns an error that tells the agent what to do; remove old notes with `Remove-McpDocument`.

Notes written by one agent are served to every agent that uses the knowledge base later. An agent that processed
untrusted content can therefore store instructions that later agents read (stored prompt injection). Enable
`-AllowWrite` only for agents and users you trust, and review agent notes before you rely on them.

## Imports

- `-Url` only accepts `http` and `https` URLs, follows at most five redirects and rejects downloads larger than
  100 MB before converting them.
- `Import-McpKnowledgeBase` imports documents that were added from files or URLs with the source type `Imported`,
  which `Update-McpDocument` never reads from its source. Otherwise an archive could name any file of the importing
  user (for example `~/.ssh/id_rsa`) or any URL of the internal network as a source, and the next
  `Update-McpDocument -All` would copy it into the knowledge base, where every agent can read it. `-TrustSource`
  keeps the sources; use it only for archives you created yourself.
- `Update-McpDocument` reads the paths and URLs stored in `manifest.json` with the rights of the current user. When
  several people work directly on a knowledge base on a share, everyone with write access to the share can choose
  these sources, so only run `Update-McpDocument` on shared knowledge bases whose writers you trust.
- `Import-McpKnowledgeBase` only extracts the expected knowledge base files from an archive and rejects entries that
  would be written outside the target folder, documents with invalid ids, more than 100000 entries and more than 1 GB
  of uncompressed content (counted while extracting, so decompression bombs are stopped).
- Word documents are read with a limit of 64 MB per decompressed part, and their XML is parsed without document type
  definitions (DTDs), so entity expansion and external entities cannot be used; documents with a DTD are rejected.
- The `claude mcp add` command from `Get-McpClientConfig` quotes every value in single quotes (PowerShell quoting on
  Windows, POSIX quoting elsewhere), so a knowledge base path or server name cannot run commands when it is pasted.
- Custom converters (`Register-McpDocumentConverter`) run arbitrary PowerShell code in your session; only register
  converters you trust.
- PDF extraction runs PSWritePDF or `pdftotext` on the imported files.

## Data at rest

Knowledge bases are plain files below `$env:PSMCPKB_HOME`. Protect the folder with file system permissions, and use
encrypted storage (for example Azure Files with encryption at rest, which is the default) for sensitive content.
Logs contain search queries and client names but no API keys and no document content.

## Reporting vulnerabilities

See [SECURITY.md](../SECURITY.md).
