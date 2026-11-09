# Security

MCPPosh gives AI agents read access (and optionally write access) to your documentation. This page explains the
security model and recommendations.

## What agents can access

- An MCPPosh server provides exactly one knowledge base. Agents can search and read all of its documents, nothing
  else: no files outside the knowledge base, no commands, no other knowledge bases.
- Put only documentation into a knowledge base that every user of the connected agents may read. Use separate
  knowledge bases (and servers) for different audiences.
- Content of documents is passed to the language model. Do not import secrets such as passwords or API keys.
- Documents can contain text that tries to instruct the model (prompt injection), especially content imported from
  the web. Import web pages only from sources you trust.

## stdio servers

stdio servers are started by the AI client with the rights of the current user and only talk to that client through
stdin and stdout. They do not open network ports.

## HTTP servers

- **Loopback by default**: servers listen on `localhost` unless `-ListenAddress` says otherwise.
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
- **No TLS**: the server speaks plain HTTP. Use HTTPS through a reverse proxy or a platform ingress (the Azure
  template does this) whenever traffic leaves the machine.
- **Health endpoint**: `/health` only reports `status`, `server` and `version` without a key.
- **Request size**: request bodies are limited to 10 MB.

## Write access

`add_note` is only offered when the server runs with `-AllowWrite`. Agent notes are stored with the source type
`Agent` and the tag `agent-note`, can only add or update notes (never change or delete other documents) and are
limited to 200000 characters. Review them regularly with `Get-McpDocument -SourceType Agent`.

## Imports

- `-Url` only accepts `http` and `https` URLs and follows at most five redirects.
- `Import-McpKnowledgeBase` only extracts the expected knowledge base files from an archive and rejects entries that
  would be written outside the target folder.
- Custom converters (`Register-McpDocumentConverter`) run arbitrary PowerShell code in your session; only register
  converters you trust.
- PDF extraction runs PSWritePDF or `pdftotext` on the imported files.

## Data at rest

Knowledge bases are plain files below `$env:MCPPOSH_HOME`. Protect the folder with file system permissions, and use
encrypted storage (for example Azure Files with encryption at rest, which is the default) for sensitive content.
Logs contain search queries and client names but no API keys and no document content.

## Reporting vulnerabilities

See [SECURITY.md](../SECURITY.md).
