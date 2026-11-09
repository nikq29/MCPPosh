---
external help file: MCPPosh-help.xml
GeneratedBy: Sampler update_help_source task
Module Name: MCPPosh
online version: https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Restart-McpServer.md
schema: 2.0.0
---

# Restart-McpServer

## SYNOPSIS
Restarts local MCPPosh HTTP servers with their previous settings.

## SYNTAX

```
Restart-McpServer [[-KnowledgeBase] <String>] [-Port <Int32>] [-ApiKey <String[]>]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
API keys are never stored.
If the server required an API key, pass -ApiKey again or set
$env:MCPPOSH_API_KEY.

## EXAMPLES

### EXAMPLE 1
```
Restart-McpServer -KnowledgeBase Contoso
```

Restarts the local HTTP server of the knowledge base Contoso with its previous port and options.

### EXAMPLE 2
```
Restart-McpServer -Port 8080 -ApiKey $key
```

Restarts the server on port 8080.
API keys are never stored, so servers with authentication need the key again.

## PARAMETERS

### -KnowledgeBase
Restart the local HTTP servers of this knowledge base (name, wildcard or directory path).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Port
Restart the local HTTP server that listens on this port.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -ApiKey
API keys for the restarted server.
Required when the server used API keys, because keys are never stored.

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

### MCPPosh.Server. You can pipe servers from Get-McpServer; KnowledgeBase and Port bind by property name.
## OUTPUTS

### MCPPosh.Server: KnowledgeBase, Transport, Status (Running or Stopped), Url, Port, ListenAddress, ProcessId, StartedAt, Uptime, AuthRequired, AllowWrite, AllowAnonymous, AllowedOrigins, LogFile, KnowledgeBasePath and Version.
## NOTES

## RELATED LINKS

[https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Restart-McpServer.md](https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Restart-McpServer.md)

[Start-McpServer]()

[Stop-McpServer]()

[Get-McpServer]()

