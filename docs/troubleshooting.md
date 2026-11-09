# Troubleshooting

Start with the end-to-end test and the logs; they explain most problems:

```powershell
Test-McpServer -KnowledgeBase Contoso -Query 'test'              # stdio, like AI clients
Test-McpServer -Uri http://localhost:5050 -ApiKey $key           # HTTP
Get-McpServerLog -KnowledgeBase Contoso -Tail 50
```

## The AI client does not show the tools

- Run `Test-McpServer -KnowledgeBase <name>`. If it fails, fix that error first.
- Check the client configuration: regenerate it with `Get-McpClientConfig` and compare. The `command` must be the
  full path of `pwsh` (PowerShell 7), not `powershell.exe` (Windows PowerShell 5.1).
- If the configuration imports the module by path, the path must still exist. After installing MCPPosh from the
  Gallery, regenerate the configuration so it imports the module by name.
- When `$env:MCPPOSH_HOME` is set in your shell but not in the client configuration, the server looks for the
  knowledge base in `~/.mcpposh`. `Get-McpClientConfig` adds the variable to the `env` section automatically.
- Restart the client after changing its configuration.
- Look at `server-stdio.log` of the knowledge base: every start writes `stdio server started` and every connection
  `initialize from <client>`.

## "The stdio server wrote non-JSON output to stdout"

Something printed to stdout before or while the server ran, which breaks the stdio protocol. Common causes are a
PowerShell profile (always use `-NoProfile`) or a custom converter or module that writes to the host when it is
imported. The generated client configuration already uses `-NoLogo -NoProfile -NonInteractive`.

## "Knowledge base '…' was not found"

Create it with `New-McpKnowledgeBase -Name <name>` or check `$env:MCPPOSH_HOME`. Only the knowledge base `Default`
is created automatically.

## Port problems

- "Port 5050 is already in use": choose another port with `-Port`, or find the process with `Get-McpServer` (MCPPosh
  servers) or `Get-NetTCPConnection -LocalPort 5050` (Windows) / `ss -ltnp` (Linux).
- "An MCPPosh server is already running on port …": stop it with `Stop-McpServer -Port <port>`.
- Windows, "Could not listen on http://+:…/ : Access is denied": listening on all interfaces requires administrator
  rights or a URL reservation: `netsh http add urlacl url=http://+:5050/ user=DOMAIN\user`.
- Windows, `400 Bad Request - Invalid Hostname` for `http://127.0.0.1:…`: the Windows HTTP stack only accepts the
  host name the server listens on; use `http://localhost:…`.

## HTTP status codes

| Code | Cause | Fix |
| --- | --- | --- |
| 401 | missing or wrong API key | send `Authorization: Bearer <key>` or `X-API-Key`; after a restart pass `-ApiKey` again |
| 403 | browser origin not allowed | add the origin with `-AllowedOrigin` |
| 405 | `GET /mcp` or wrong method | MCP requests use `POST /mcp`; the server has no SSE stream |
| 400 | unsupported `MCP-Protocol-Version` header | update the client or remove the header |
| 413 | request larger than 10 MB | send smaller requests |

## Background server does not start

`Start-McpServer` shows the last lines of the error output. The complete output is in
`<knowledge base>/logs/server-<port>.stderr.log` and `server-<port>.stdout.log`. Run the server in the foreground to
see errors directly:

```powershell
Start-McpServer -KnowledgeBase Contoso -Port 5050 -Foreground
```

A server that no longer runs is shown once as `Stopped` by `Get-McpServer`.

## Import problems

| Problem | Solution |
| --- | --- |
| "PDF support requires the PowerShell module 'PSWritePDF' … or the 'pdftotext' tool" | install one of them, see [PDF support](adding-knowledge.md#pdf-support), then `Update-McpDocument -All -Force` |
| PDF documents are empty | the PDF is scanned and has no text layer; run OCR first |
| "… is not a valid Word document" | only `.docx` is supported; save `.doc` files as `.docx` |
| "No converter found for …" | the file is binary and has no converter; use `-Format` or `Register-McpDocumentConverter` |
| "Only absolute http(s) URLs are supported" | use a complete `http://` or `https://` URL |
| a file is not imported from a folder | add `-Recurse`; files in `.git`, `node_modules` and similar folders are skipped |
| the same file appears twice | files are matched by full path; the same content at two paths creates two documents |
| custom converter is missing after a restart | registrations last for one session; add them to your profile |

## Search finds nothing or the wrong sections

- Check with `Search-McpDocument` and use specific keywords from the documents; stop words are ignored.
- Make sure the document is in the knowledge base the server provides (`Get-McpDocument -KnowledgeBase …`).
- Improve titles and headings; they are weighted higher.
- Split very long documents into focused sections.
- Tag filters only return documents with at least one of the given tags.

See [Search](search.md) for how ranking works.

## A running server does not see new documents

Servers reload when `manifest.json` changes, at most once per second. Check that the server provides the knowledge
base you changed (`Get-McpServer` shows `KnowledgeBasePath`) and that the change was written to the same folder. On
network shares, verify that file timestamps are updated. `Restart-McpServer` forces a reload.

## Azure

- The container restarts or never becomes healthy: check `az containerapp logs show -n <name> -g <rg>`; a missing
  `MCPPOSH_API_KEY` stops the server with an error.
- Permission errors on `/data`: the share must be mounted with `uid=1654,gid=1654` (the template does this).
- `Publish-McpKnowledgeBase` fails with an Az error: run `Connect-AzAccount`, check that `Az.Storage` is installed
  and that your account can read the storage account keys (or use `-SasToken`).
- New documents do not appear: `-RemoteName` (or the local name) must match `MCPPOSH_KNOWLEDGEBASE` of the container.

## Collecting information for an issue

```powershell
$PSVersionTable.PSVersion
(Get-Module MCPPosh -ListAvailable).Version
Get-McpKnowledgeBase -Name Contoso | Format-List
Test-McpServer -KnowledgeBase Contoso | Format-List
Get-McpServerLog -KnowledgeBase Contoso -Tail 100
```

Remove confidential content before you attach logs to an issue.
