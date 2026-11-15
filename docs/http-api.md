# HTTP API

HTTP servers implement the Streamable HTTP transport of the Model Context Protocol. They answer every request with
JSON and keep no session state.

## Endpoints

| Method | Path | Description |
| --- | --- | --- |
| `POST` | `/mcp` | JSON-RPC requests, notifications and batches |
| `GET`, `DELETE` | `/mcp` | `405 Method Not Allowed` (no server-initiated event stream, no sessions) |
| `OPTIONS` | `/mcp` | CORS preflight, `204 No Content` |
| `GET`, `HEAD` | `/health` | health status; details only for authorized callers |
| `GET`, `HEAD` | `/.well-known/oauth-protected-resource`, `/.well-known/oauth-protected-resource/mcp` | OAuth protected resource metadata (only with OAuth) |
| `GET`, `HEAD` | `/` | short plain-text description of the server |

Other paths return `404 Not Found`.

## Authentication

When the server has API keys (`-ApiKey` or `PSMCPKB_API_KEY`), every request to `/mcp` must contain one of them:

```http
Authorization: Bearer <key>
```

or

```http
X-API-Key: <key>
```

Requests without a valid key get `401 Unauthorized` with `WWW-Authenticate: Bearer realm="PSMcpKnowledgeBase"` and a JSON-RPC
error with code -32001. Keys are compared in constant time. Several keys can be configured at the same time, for
example to rotate keys without downtime.

Servers that listen on a non-loopback address require API keys or OAuth unless they were started with
`-AllowAnonymous`.

### OAuth

With `-OAuthIssuer` and `-OAuthAudience` (or `PSMCPKB_OAUTH_ISSUER` and `PSMCPKB_OAUTH_AUDIENCE`) the server also
accepts OAuth access tokens of an OpenID Connect identity provider such as Microsoft Entra ID, Auth0 or Keycloak, as
described in the MCP authorization specification. The server only checks tokens; the AI client signs the user in.

- `Authorization: Bearer <token>` is first compared with the API keys, then checked as a JSON Web Token: RS256
  signature with the issuer's keys (from `<issuer>/.well-known/openid-configuration`), exact issuer, one of the
  audiences, expiry and not-before (five minutes clock skew) and, with `-OAuthScope`, the scope in the `scp` or `scope`
  claim. The short scope name (`access_as_user` for `api://<app>/access_as_user`) is accepted too, because Entra ID
  writes it that way.
- `401` responses add `resource_metadata="<base>/.well-known/oauth-protected-resource/mcp"` (and `scope="..."`) to
  `WWW-Authenticate`. Clients read the metadata there: `resource` (`<base>/mcp`), `authorization_servers` (the
  issuer), `scopes_supported` and `bearer_methods_supported`.
- Behind a reverse proxy, `<base>` is taken from `X-Forwarded-Proto` and `X-Forwarded-Host` (host names only).
- The signing keys are cached; unknown key ids load them again at most once per minute.

```powershell
$tenant = '<tenant id>'; $client = '<client id>'
Start-McpServer -KnowledgeBase Contoso -ListenAddress '*' -Port 8080 -Foreground `
    -OAuthIssuer "https://login.microsoftonline.com/$tenant/v2.0" -OAuthAudience $client, "api://$client" `
    -OAuthScope "api://$client/access_as_user"
```

Microsoft Entra ID does not support dynamic client registration, so clients need the client ID of an app
registration, for example `claude mcp add --transport http --client-id <client id> --callback-port <port> ...`
(see [Azure hosting](hosting-azure.md#sign-in-with-microsoft-entra-id)).

## POST /mcp

Send a JSON-RPC 2.0 message as the request body with `Content-Type: application/json`; other content types are
rejected with `415 Unsupported Media Type`. Clients should send `Accept: application/json, text/event-stream`.

| Request | Response |
| --- | --- |
| request with `id` | `200 OK`, `Content-Type: application/json`, JSON-RPC response |
| notification without `id` | `202 Accepted`, empty body |
| batch (array) | `200 OK` with an array of responses, or `202` when it contained only notifications |

Optional header `MCP-Protocol-Version`: when it names a version the server does not support, the request is rejected
with `400 Bad Request`. Supported versions are `2025-11-25`, `2025-06-18`, `2025-03-26` and `2024-11-05`.

Request bodies larger than 10 MB are rejected with `413 Payload Too Large`. The size is counted while the body is
read, so the limit also applies to chunked requests without `Content-Length`. A batch may contain at most 100
messages.

The complete request body must arrive within 30 seconds. Otherwise the server answers `408 Request Timeout` and closes
the connection. The server handles one request at a time, so this keeps a client that stops sending from blocking
everyone else.

## Origin check and CORS

Browsers send an `Origin` header. The server

- allows requests without `Origin`,
- allows origins listed with `-AllowedOrigin` (or `PSMCPKB_ALLOWED_ORIGINS`) and answers them with CORS headers
  (`Access-Control-Allow-Origin`, `-Headers`, `-Methods`, `-Expose-Headers`),
- otherwise allows only `localhost`, `127.0.0.1` and `::1` origins when it listens on a loopback address (protection
  against DNS rebinding),
- on other addresses allows all origins when the server requires an API key (a foreign web page cannot know the key),
  and no browser origins when it runs with `-AllowAnonymous` (a gateway may authenticate with cookies that a foreign
  page could ride on),
- rejects all other origins with `403 Forbidden`.

## GET /health

```json
{"status":"ok","server":"PSMcpKnowledgeBase"}
```

With a valid API key (or when the server has no keys) the response also contains `version`, `knowledgeBase`,
`description`, `documents`, `chunks`, `revision`, `allowWrite`, `authRequired`, `uptimeSeconds` and `requests`. Use
`/health` for container probes; it never requires a key. The root page `/` likewise names the knowledge base only for
authorized callers.

## Status codes

| Code | When |
| --- | --- |
| 200 | JSON-RPC response, health, root page |
| 202 | notification accepted |
| 204 | CORS preflight |
| 400 | unsupported `MCP-Protocol-Version` |
| 401 | missing or invalid API key or access token |
| 403 | origin not allowed |
| 404 | unknown path |
| 405 | wrong method for the path |
| 408 | request body not received within 30 seconds (the connection is closed) |
| 413 | request body larger than 10 MB |
| 415 | `POST /mcp` without `Content-Type: application/json` |
| 500 | unexpected server error |

All responses contain `Cache-Control: no-store` and `X-Content-Type-Options: nosniff`.

## Examples

```bash
curl -s http://localhost:5050/health

curl -s http://localhost:5050/mcp \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"curl","version":"1"}}}'

curl -s http://localhost:5050/mcp \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"search_documentation","arguments":{"query":"vpn error 809"}}}'
```

```powershell
$headers = @{ Authorization = "Bearer $key" }
$body = @{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = @{ name = 'list_documents'; arguments = @{} } } | ConvertTo-Json -Depth 5
(Invoke-RestMethod -Uri http://localhost:5050/mcp -Method Post -Body $body -ContentType 'application/json' -Headers $headers).result.content[0].text
```

The JSON-RPC methods, tools and errors are described in [MCP server](mcp-server.md).
