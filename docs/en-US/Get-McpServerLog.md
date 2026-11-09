---
external help file: MCPPosh-help.xml
GeneratedBy: Sampler update_help_source task
Module Name: MCPPosh
online version: https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Get-McpServerLog.md
schema: 2.0.0
---

# Get-McpServerLog

## SYNOPSIS
Shows the log of an MCP server.

## SYNTAX

### Latest (Default)
```
Get-McpServerLog [[-KnowledgeBase] <String>] [-Tail <Int32>] [-Wait]
 [<CommonParameters>]
```

### Port
```
Get-McpServerLog [[-KnowledgeBase] <String>] [-Port <Int32>] [-Tail <Int32>] [-Wait]
 [<CommonParameters>]
```

### Stdio
```
Get-McpServerLog [[-KnowledgeBase] <String>] [-Stdio] [-Tail <Int32>] [-Wait]
 [<CommonParameters>]
```

## DESCRIPTION
Each knowledge base keeps its server logs in \<knowledge base\>/logs: server-\<port\>.log for
HTTP servers and server-stdio.log for servers started by AI clients over stdio.

## EXAMPLES

### EXAMPLE 1
```
Get-McpServerLog -KnowledgeBase Contoso -Tail 20
```

Shows the last 20 lines of the most recently written server log of the knowledge base Contoso.

### EXAMPLE 2
```
Get-McpServerLog -KnowledgeBase Contoso -Stdio -Wait
```

Follows the log of the stdio servers that AI clients start, until Ctrl+C is pressed.

## PARAMETERS

### -KnowledgeBase
Knowledge base whose log to show.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: Default
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Port
Show the log of the HTTP server on this port.

```yaml
Type: Int32
Parameter Sets: Port
Aliases:

Required: False
Position: Named
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Stdio
Show the log of stdio servers (started by AI clients).

```yaml
Type: SwitchParameter
Parameter Sets: Stdio
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Tail
Number of lines from the end of the log.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 50
Accept pipeline input: False
Accept wildcard characters: False
```

### -Wait
Keep following the log (like tail -f) until Ctrl+C.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### MCPPosh.Server. KnowledgeBase and Port bind by property name, for example from Get-McpServer.
## OUTPUTS

### System.String. The lines of the log file.
## NOTES

## RELATED LINKS

[https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Get-McpServerLog.md](https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Get-McpServerLog.md)

[Get-McpServer]()

[Start-McpServer]()

