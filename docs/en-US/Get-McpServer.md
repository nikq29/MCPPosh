---
external help file: MCPPosh-help.xml
GeneratedBy: Sampler update_help_source task
Module Name: MCPPosh
online version: https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Get-McpServer.md
schema: 2.0.0
---

# Get-McpServer

## SYNOPSIS
Shows MCPPosh HTTP servers: local background/foreground servers, or a remote server.

## SYNTAX

### Local (Default)
```
Get-McpServer [[-KnowledgeBase] <String>] [-Port <Int32>]
 [<CommonParameters>]
```

### Remote
```
Get-McpServer -Uri <Uri> [-ApiKey <String>] [<CommonParameters>]
```

## DESCRIPTION
Without -Uri, lists the HTTP servers started on this machine.
Servers whose process is
gone are reported once with Status 'Stopped' and then forgotten.

With -Uri, queries the /health endpoint of a (remote) server, e.g.
one hosted in Azure.

## EXAMPLES

### EXAMPLE 1
```
Get-McpServer
```

Lists the HTTP servers started on this machine with status, URL and process id.

### EXAMPLE 2
```
Get-McpServer -Uri https://mcpposh.azurecontainerapps.io/mcp -ApiKey $key | Format-List
```

Queries the health endpoint of a hosted server and shows its knowledge base, number of documents, revision and uptime.

## PARAMETERS

### -KnowledgeBase
Only servers for this knowledge base.

```yaml
Type: String
Parameter Sets: Local
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Port
Only the server on this port.

```yaml
Type: Int32
Parameter Sets: Local
Aliases:

Required: False
Position: Named
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Uri
Base URL or MCP endpoint of a remote server, e.g.
https://docs-mcp.contoso.com/mcp.

```yaml
Type: Uri
Parameter Sets: Remote
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ApiKey
API key for the remote server (needed to see details such as the document count).

```yaml
Type: String
Parameter Sets: Remote
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### MCPPosh.Server. KnowledgeBase and Port bind by property name.
## OUTPUTS

### MCPPosh.Server: KnowledgeBase, Transport, Status (Running or Stopped), Url, Port, ListenAddress, ProcessId, StartedAt, Uptime, AuthRequired, AllowWrite, AllowAnonymous, AllowedOrigins, LogFile, KnowledgeBasePath and Version. Remote servers (-Uri) additionally report Documents, Revision and Error.
## NOTES

## RELATED LINKS

[https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Get-McpServer.md](https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Get-McpServer.md)

[Start-McpServer]()

[Stop-McpServer]()

[Test-McpServer]()

[Get-McpServerLog]()

