---
external help file: MCPPosh-help.xml
GeneratedBy: Sampler update_help_source task
Module Name: MCPPosh
online version: https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Remove-McpDocument.md
schema: 2.0.0
---

# Remove-McpDocument

## SYNOPSIS
Removes documents from a knowledge base.

## SYNTAX

```
Remove-McpDocument [-Id] <String[]> [-KnowledgeBase <String>] [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Removes documents from a knowledge base, including their Markdown content and search index.
Running MCP servers stop returning the documents automatically.

## EXAMPLES

### EXAMPLE 1
```
Remove-McpDocument -Id old-runbook-1a2b3c
```

Removes one document from the knowledge base Default after confirmation.

### EXAMPLE 2
```
Get-McpDocument -Tag obsolete | Remove-McpDocument -Confirm:$false
```

Removes all documents with the tag obsolete without asking for confirmation.

## PARAMETERS

### -Id
Ids of the documents to remove.
Accepts the Id property of objects from Get-McpDocument through the pipeline.

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

### -KnowledgeBase
Name or directory path of the knowledge base that contains the documents.
Defaults to Default.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: Default
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

### MCPPosh.Document. You can pipe documents from Get-McpDocument; Id and KnowledgeBase bind by property name.
## OUTPUTS

### None.
## NOTES

## RELATED LINKS

[https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Remove-McpDocument.md](https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Remove-McpDocument.md)

[Get-McpDocument]()

[Add-McpDocument]()

