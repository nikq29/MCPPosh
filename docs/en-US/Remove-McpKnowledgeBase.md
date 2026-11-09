---
external help file: MCPPosh-help.xml
GeneratedBy: Sampler update_help_source task
Module Name: MCPPosh
online version: https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Remove-McpKnowledgeBase.md
schema: 2.0.0
---

# Remove-McpKnowledgeBase

## SYNOPSIS
Deletes a knowledge base including all of its documents.

## SYNTAX

```
Remove-McpKnowledgeBase [-Name] <String[]> [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
Deletes a knowledge base folder including all documents, the search index and the logs.
Knowledge bases that are served by a running MCP server are not removed.

## EXAMPLES

### EXAMPLE 1
```
Remove-McpKnowledgeBase -Name OldDocs
```

Deletes the knowledge base OldDocs after confirmation.

### EXAMPLE 2
```
Remove-McpKnowledgeBase -Name Test -Confirm:$false
```

Deletes the knowledge base Test without asking.
Stop servers of the knowledge base first.

## PARAMETERS

### -Name
Names or directory paths of the knowledge bases to delete.
Accepts the Name property through the pipeline.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
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

### System.String. You can pipe objects with a Name property, for example from Get-McpKnowledgeBase.
## OUTPUTS

### None.
## NOTES

## RELATED LINKS

[https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Remove-McpKnowledgeBase.md](https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Remove-McpKnowledgeBase.md)

[Get-McpKnowledgeBase]()

[Export-McpKnowledgeBase]()

[Stop-McpServer]()

