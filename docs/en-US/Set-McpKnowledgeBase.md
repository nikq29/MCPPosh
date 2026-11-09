---
external help file: MCPPosh-help.xml
GeneratedBy: Sampler update_help_source task
Module Name: MCPPosh
online version: https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Set-McpKnowledgeBase.md
schema: 2.0.0
---

# Set-McpKnowledgeBase

## SYNOPSIS
Changes the description of a knowledge base.

## SYNTAX

```
Set-McpKnowledgeBase [-Name] <String> -Description <String> [-PassThru]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
The description is sent to the AI agent as MCP server instructions.
Running servers pick
up the change automatically.

## EXAMPLES

### EXAMPLE 1
```
Set-McpKnowledgeBase -Name Contoso -Description 'Runbooks and architecture of the Contoso platform. Use it for any question about Contoso.'
```

Changes the description that AI agents receive as server instructions.
Running servers pick up the change automatically.

## PARAMETERS

### -Name
Name or directory path of the knowledge base to change.
Accepts the Name property through the pipeline.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Description
New description of the knowledge base.
It is sent to AI agents as MCP server instructions.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PassThru
Returns the updated knowledge base object.
By default the cmdlet does not produce output.

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

### System.String. You can pipe objects with a Name property, for example from Get-McpKnowledgeBase.
## OUTPUTS

### None by default. With -PassThru: MCPPosh.KnowledgeBase: Name, Description, Documents, Characters, Tags, Revision, Created, Updated and Path.
## NOTES

## RELATED LINKS

[https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Set-McpKnowledgeBase.md](https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Set-McpKnowledgeBase.md)

[Get-McpKnowledgeBase]()

[New-McpKnowledgeBase]()

