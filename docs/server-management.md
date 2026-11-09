# Server management

MCPPosh servers are started, inspected and stopped with PowerShell. stdio servers are started by AI clients and end
when the client closes the connection; this page is mostly about HTTP servers.

## Start a server

```powershell
# Background HTTP server on http://localhost:5050/mcp
Start-McpServer -KnowledgeBase Contoso

# With API key, write access and another port
Start-McpServer -KnowledgeBase Contoso -Port 5051 -ApiKey $key -AllowWrite

# Reachable from the network (API key required)
Start-McpServer -KnowledgeBase Contoso -ListenAddress '*' -Port 8080 -ApiKey $key

# In the current console until Ctrl+C (containers, troubleshooting)
Start-McpServer -KnowledgeBase Contoso -Foreground

# stdio, as used by AI clients
Start-McpServer -KnowledgeBase Contoso -Transport Stdio
```

| Parameter | Default | Description |
| --- | --- | --- |
| `-KnowledgeBase` | `Default` | name or path of the knowledge base |
| `-Transport` | `Http` | `Http` or `Stdio` |
| `-Port` | `5050` | TCP port of the HTTP server |
| `-ListenAddress` | `localhost` | `localhost` (local only), `*` (all interfaces) or a host name |
| `-ApiKey` | `$env:MCPPOSH_API_KEY` | one or more accepted API keys |
| `-AllowedOrigin` | none | browser origins allowed through CORS |
| `-AllowWrite` | off | offers the `add_note` tool |
| `-AllowAnonymous` | off | allows a non-loopback address without API key (only behind an authenticating gateway) |
| `-Foreground` | off | runs the HTTP server in the current process |
| `-StartTimeoutSeconds` | `30` | how long to wait for a background server to become healthy |

### How background servers run

Without `-Foreground`, `Start-McpServer` starts a hidden PowerShell process that imports the same module and runs
`Start-McpServer -Foreground`:

- On Windows the process window is hidden; on Linux it is detached from the terminal with `setsid`, so closing the
  terminal does not stop the server.
- API keys are handed over in the `MCPPOSH_API_KEY` environment variable of the child process, never on the command
  line.
- `Start-McpServer` waits until the server writes its state file and answers `/health`, then returns a
  `MCPPosh.Server` object. If the server does not start, the last lines of its error output are shown.
- The start is refused when another MCPPosh server is registered for the port or the port is already in use.

Background servers do not survive a reboot. For permanent hosting use a container ([Docker](hosting-docker.md),
[Azure](hosting-azure.md)), a scheduled task at startup or a systemd unit that runs
`pwsh -NoProfile -Command "Import-Module MCPPosh; Start-McpServer -KnowledgeBase Contoso -Foreground"`.

## Show servers

```powershell
Get-McpServer
Get-McpServer -KnowledgeBase Contoso
Get-McpServer -Port 5050 | Format-List
```

The output contains `KnowledgeBase`, `Transport`, `Status`, `Url`, `Port`, `ListenAddress`, `ProcessId`, `StartedAt`,
`Uptime`, `AuthRequired`, `AllowWrite`, `AllowAnonymous`, `AllowedOrigins`, `LogFile`, `KnowledgeBasePath` and
`Version`. A server whose process no longer exists is shown once with status `Stopped` and then forgotten.

Remote servers, for example in Azure, are queried through their health endpoint:

```powershell
Get-McpServer -Uri https://mcpposh.example.com/mcp -ApiKey $key | Format-List
```

The status is `Running`, `Unauthorized` (wrong key), `Unreachable` or `HTTP <code>`; with a valid key the result also
contains `KnowledgeBase`, `Documents`, `Revision`, `Uptime`, `AuthRequired`, `AllowWrite` and `Version`.

## Stop and restart

```powershell
Stop-McpServer -KnowledgeBase Contoso
Stop-McpServer -Port 5050
Stop-McpServer -All
Get-McpServer | Stop-McpServer

Restart-McpServer -KnowledgeBase Contoso
Restart-McpServer -Port 5051 -ApiKey $key
```

- Without parameters, `Stop-McpServer` stops the only running server and refuses to guess when several are running.
- The process id and its start time are checked before a process is stopped, so a reused process id never stops an
  unrelated process.
- `Restart-McpServer` restarts with the stored port, listen address and options. API keys are never stored: pass
  `-ApiKey` again or set `$env:MCPPOSH_API_KEY` for servers with authentication.
- Both cmdlets support `-WhatIf` and `-Confirm`.

## Test a server

`Test-McpServer` behaves like an AI client: it performs the MCP handshake, lists the tools, counts the documents and
optionally runs a search.

```powershell
Test-McpServer -KnowledgeBase Contoso -Query 'VPN'                         # stdio, as started by AI clients
Test-McpServer -Uri http://localhost:5050 -ApiKey $key -Query 'VPN'        # HTTP, local or remote
```

The result contains `Target`, `Transport`, `Success`, `ProtocolVersion`, `ServerName`, `ServerVersion`, `Instructions`,
`Tools`, `Documents`, `SearchResults`, `TopResult`, `ElapsedMs` and `Error`. Failures are reported in `Error` instead
of being thrown, so the cmdlet is suitable for monitoring scripts:

```powershell
$result = Test-McpServer -Uri https://mcpposh.example.com -ApiKey $key
if (-not $result.Success) { Write-Warning "MCPPosh is unhealthy: $($result.Error)" }
```

## Logs

Each knowledge base keeps the logs of its servers in `<knowledge base>/logs`:

| File | Written by |
| --- | --- |
| `server-stdio.log` | stdio servers started by AI clients |
| `server-<port>.log` | HTTP servers |
| `server-<port>.stdout.log`, `server-<port>.stderr.log` | console output of background processes (startup errors) |

```powershell
Get-McpServerLog -KnowledgeBase Contoso                 # most recent log, last 50 lines
Get-McpServerLog -KnowledgeBase Contoso -Port 5050 -Tail 200
Get-McpServerLog -KnowledgeBase Contoso -Stdio -Wait    # follow the stdio log
```

Log lines contain a UTC timestamp, a level (`INFO`, `WARN`, `ERROR`, `DEBUG`) and the message, for example the client
name on `initialize`, every search with its number of results, rejected requests and every HTTP request with its
status code and duration. Foreground HTTP servers also write the log lines to the console, which makes them visible
in `docker logs` and Azure Log Analytics.

## Several servers

Every server provides exactly one knowledge base. Run several servers on different ports to provide several
knowledge bases:

```powershell
Start-McpServer -KnowledgeBase Contoso -Port 5050 -ApiKey $key
Start-McpServer -KnowledgeBase Product -Port 5060 -ApiKey $key
```

Any number of stdio servers can run at the same time, because every AI client starts its own process.
