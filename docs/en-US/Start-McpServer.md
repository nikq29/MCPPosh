---
external help file: MCPPosh-help.xml
GeneratedBy: Sampler update_help_source task
Module Name: MCPPosh
online version: https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Start-McpServer.md
schema: 2.0.0
---

# Start-McpServer

## SYNOPSIS
Starts an MCP server that provides a knowledge base to AI agents.

## SYNTAX

```
Start-McpServer [[-KnowledgeBase] <String>] [-Transport <String>] [-Port <Int32>] [-ListenAddress <String>]
 [-ApiKey <String[]>] [-AllowedOrigin <String[]>] [-AllowWrite] [-AllowAnonymous] [-Foreground]
 [-StartTimeoutSeconds <Int32>] [-BackgroundChild] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
Transport 'Stdio' runs the server in the current process and talks JSON-RPC over
stdin/stdout.
This is what AI clients such as Claude Desktop, Claude Code, VS Code or
Cursor start themselves; see Get-McpClientConfig for ready-to-use configuration.

Transport 'Http' (default) serves the Streamable HTTP transport on http://\<address\>:\<port\>/mcp.
Without -Foreground the server is started as a hidden background PowerShell process that
you manage with Get-McpServer, Stop-McpServer, Restart-McpServer and Get-McpServerLog.
Use -Foreground for containers (e.g.
Azure Container Apps) or debugging.

Documents added or changed while the server runs are picked up automatically.

## EXAMPLES

### EXAMPLE 1
```
Start-McpServer -KnowledgeBase Contoso
```

Starts a hidden background HTTP server on http://localhost:5050/mcp and returns its status.

### EXAMPLE 2
```
Start-McpServer -KnowledgeBase Contoso -Transport Stdio
```

Runs the server over stdin/stdout.
AI clients use this command in their configuration; see Get-McpClientConfig.

### EXAMPLE 3
```
Start-McpServer -KnowledgeBase Contoso -Port 8080 -ListenAddress '*' -ApiKey $key -Foreground
```

Runs an HTTP server reachable from the network in the current console, for example in a container.
Clients must send the API key.

### EXAMPLE 4
```
Start-McpServer -KnowledgeBase Contoso -Port 5051 -ApiKey $key -AllowWrite
```

Starts a background server that additionally offers the add_note tool, so agents can store new knowledge.

## PARAMETERS

### -KnowledgeBase
Name or directory path of the knowledge base to serve.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: Default
Accept pipeline input: False
Accept wildcard characters: False
```

### -Transport
Stdio runs the server over stdin/stdout for AI clients; Http serves the Streamable HTTP transport (default).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: Http
Accept pipeline input: False
Accept wildcard characters: False
```

### -Port
TCP port for the HTTP transport.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 5050
Accept pipeline input: False
Accept wildcard characters: False
```

### -ListenAddress
Address to listen on.
'localhost' (default) only accepts local connections.
Use '*' to
listen on all interfaces (requires -ApiKey or -AllowAnonymous; on Windows also admin
rights or a URL ACL: netsh http add urlacl url=http://+:\<port\>/ user=\<user\>).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: Localhost
Accept pipeline input: False
Accept wildcard characters: False
```

### -ApiKey
One or more API keys.
Clients must send 'Authorization: Bearer \<key\>' or 'X-API-Key: \<key\>'.
Defaults to the comma-separated keys in $env:MCPPOSH_API_KEY.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -AllowedOrigin
Browser origins allowed to call the server (CORS), e.g.
https://my-app.example.com.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -AllowWrite
Adds the add_note tool so the AI agent can store new knowledge.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -AllowAnonymous
Allows listening on a non-loopback address without an API key (e.g.
behind a gateway
that authenticates requests).

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Foreground
Run the HTTP server in the current process (blocks until Ctrl+C).

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -StartTimeoutSeconds
Seconds to wait for a background HTTP server to answer its health check before the start is considered failed.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 30
Accept pipeline input: False
Accept wildcard characters: False
```

### -BackgroundChild
Internal switch used by the background process that Start-McpServer starts itself. Do not use it directly.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None. You cannot pipe objects to this cmdlet.
## OUTPUTS

### None for -Transport Stdio and for -Foreground (the server runs until it is stopped). MCPPosh.Server: KnowledgeBase, Transport, Status (Running or Stopped), Url, Port, ListenAddress, ProcessId, StartedAt, Uptime, AuthRequired, AllowWrite, AllowAnonymous, AllowedOrigins, LogFile, KnowledgeBasePath and Version. for background HTTP servers.
## NOTES

## RELATED LINKS

[https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Start-McpServer.md](https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Start-McpServer.md)

[Stop-McpServer]()

[Get-McpServer]()

[Test-McpServer]()

[Get-McpClientConfig]()

