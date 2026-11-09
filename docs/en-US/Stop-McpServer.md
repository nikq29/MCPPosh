---
external help file: MCPPosh-help.xml
GeneratedBy: Sampler update_help_source task
Module Name: MCPPosh
online version: https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Stop-McpServer.md
schema: 2.0.0
---

# Stop-McpServer

## SYNOPSIS
Stops MCPPosh HTTP servers that run on this machine.

## SYNTAX

### Filter (Default)
```
Stop-McpServer [[-KnowledgeBase] <String>] [-Port <Int32>] [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

### All
```
Stop-McpServer [-All] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Stops MCPPosh HTTP servers that run on this machine, in the background or in another console, and removes their state files.
Without parameters the only running server is stopped.

## EXAMPLES

### EXAMPLE 1
```
Stop-McpServer -KnowledgeBase Contoso
```

Stops the HTTP servers of the knowledge base Contoso.

### EXAMPLE 2
```
Get-McpServer | Stop-McpServer
```

Stops all local servers listed by Get-McpServer.

## PARAMETERS

### -KnowledgeBase
Stop the servers of this knowledge base.

```yaml
Type: String
Parameter Sets: Filter
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Port
Stop the server on this port.

```yaml
Type: Int32
Parameter Sets: Filter
Aliases:

Required: False
Position: Named
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -All
Stops all MCPPosh HTTP servers that were started on this machine.

```yaml
Type: SwitchParameter
Parameter Sets: All
Aliases:

Required: True
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

### MCPPosh.Server. You can pipe servers from Get-McpServer; KnowledgeBase and Port bind by property name.
## OUTPUTS

### None.
## NOTES

## RELATED LINKS

[https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Stop-McpServer.md](https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Stop-McpServer.md)

[Start-McpServer]()

[Get-McpServer]()

[Restart-McpServer]()

