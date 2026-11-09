---
external help file: MCPPosh-help.xml
GeneratedBy: Sampler update_help_source task
Module Name: MCPPosh
online version: https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Test-McpServer.md
schema: 2.0.0
---

# Test-McpServer

## SYNOPSIS
Checks an MCP server end-to-end like an AI client would.

## SYNTAX

### Http (Default)
```
Test-McpServer [-Uri] <Uri> [-ApiKey <String>] [-Query <String>] [-TimeoutSeconds <Int32>]
 [<CommonParameters>]
```

### Stdio
```
Test-McpServer -KnowledgeBase <String> [-Query <String>] [-TimeoutSeconds <Int32>]
 [<CommonParameters>]
```

## DESCRIPTION
Performs the MCP handshake (initialize), lists the tools, counts the documents and,
with -Query, runs a search.
Works against HTTP servers (-Uri, local or e.g.
in Azure)
and against the stdio server of a local knowledge base (-KnowledgeBase), which is
exactly what AI clients start.

## EXAMPLES

### EXAMPLE 1
```
Test-McpServer -KnowledgeBase Contoso -Query 'VPN'
```

Starts the stdio server like an AI client, performs the MCP handshake, lists the tools and runs a search.

### EXAMPLE 2
```
Test-McpServer -Uri https://mcpposh.azurecontainerapps.io -ApiKey $key
```

Checks a hosted HTTP server end to end.
Failures are reported in the Error property instead of being thrown.

## PARAMETERS

### -Uri
Base URL or MCP endpoint of an HTTP server, e.g.
http://localhost:5050/mcp.

```yaml
Type: Uri
Parameter Sets: Http
Aliases: Url

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -ApiKey
API key for the HTTP server.

```yaml
Type: String
Parameter Sets: Http
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -KnowledgeBase
Test the stdio server for this knowledge base.

```yaml
Type: String
Parameter Sets: Stdio
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Query
Optional search query to run with the search_documentation tool.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TimeoutSeconds
Seconds to wait for each response of the server before the test fails with a timeout.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### MCPPosh.Server. Objects with a Uri or Url property bind to -Uri.
## OUTPUTS

### MCPPosh.TestResult: Target, Transport, Success, ProtocolVersion, ServerName, ServerVersion, Instructions, Tools, Documents, SearchResults, TopResult, ElapsedMs and Error.
## NOTES

## RELATED LINKS

[https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Test-McpServer.md](https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Test-McpServer.md)

[Start-McpServer]()

[Get-McpServer]()

[Get-McpClientConfig]()

