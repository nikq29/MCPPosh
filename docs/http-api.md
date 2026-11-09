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
| `GET`, `HEAD` | `/` | short plain-text description of the server |

Other paths return `404 Not Found`.

## Authentication

When the server has API keys (`-ApiKey` or `MCPPOSH_API_KEY`), every request to `/mcp` must contain one of them:

```http
Authorization: Bearer <key>
```

or

```http
X-API-Key: <key>
```

Requests without a valid key get `401 Unauthorized` with `WWW-Authenticate: Bearer realm="MCPPosh"` and a JSON-RPC
error with code -32001. Keys are compared in constant time. Several keys can be configured at the same time, for
example to rotate keys without downtime.

Servers that listen on a non-loopback address require API keys unless they were started with `-AllowAnonymous`.

## POST /mcp

Send a JSON-RPC 2.0 message as the request body with `Content-Type: application/json`. Clients should send
`Accept: application/json, text/event-stream`.

| Request | Response |
| --- | --- |
| request with `id` | `200 OK`, `Content-Type: application/json`, JSON-RPC response |
| notification without `id` | `202 Accepted`, empty body |
| batch (array) | `200 OK` with an array of responses, or `202` when it contained only notifications |

Optional header `MCP-Protocol-Version`: when it names a version the server does not support, the request is rejected
with `400 Bad Request`. Supported versions are `2025-11-25`, `2025-06-18`, `2025-03-26` and `2024-11-05`.

Request bodies larger than 10 MB are rejected with `413 Payload Too Large`.

## Origin check and CORS

Browsers send an `Origin` header. The server

- allows requests without `Origin`,
- allows origins listed with `-AllowedOrigin` (or `MCPPOSH_ALLOWED_ORIGINS`) and answers them with CORS headers
  (`Access-Control-Allow-Origin`, `-Headers`, `-Methods`, `-Expose-Headers`),
- otherwise allows only `localhost`, `127.0.0.1` and `::1` origins when it listens on a loopback address (protection
  against DNS rebinding), and all origins when it listens on other addresses,
- rejects all other origins with `403 Forbidden`.

## GET /health

```json
{"status":"ok","server":"MCPPosh","version":"0.1.0"}
```

With a valid API key (or when the server has no keys) the response also contains `knowledgeBase`, `description`,
`documents`, `chunks`, `revision`, `allowWrite`, `authRequired`, `uptimeSeconds` and `requests`. Use `/health` for
container probes; it never requires a key.

## Status codes

| Code | When |
| --- | --- |
| 200 | JSON-RPC response, health, root page |
| 202 | notification accepted |
| 204 | CORS preflight |
| 400 | unsupported `MCP-Protocol-Version` |
| 401 | missing or invalid API key |
| 403 | origin not allowed |
| 404 | unknown path |
| 405 | wrong method for the path |
| 413 | request body larger than 10 MB |
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
