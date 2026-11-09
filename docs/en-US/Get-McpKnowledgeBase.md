---
external help file: MCPPosh-help.xml
GeneratedBy: Sampler update_help_source task
Module Name: MCPPosh
online version: https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Get-McpKnowledgeBase.md
schema: 2.0.0
---

# Get-McpKnowledgeBase

## SYNOPSIS
Lists knowledge bases or gets a specific one.

## SYNTAX

```
Get-McpKnowledgeBase [[-Name] <String[]>] [<CommonParameters>]
```

## DESCRIPTION
Lists the knowledge bases below $env:MCPPOSH_HOME (or ~/.mcpposh) or returns a specific one, including the number of documents, characters, tags and the current revision.

## EXAMPLES

### EXAMPLE 1
```
Get-McpKnowledgeBase
```

Lists all knowledge bases with their number of documents and last update.

### EXAMPLE 2
```
Get-McpKnowledgeBase -Name Contoso | Format-List
```

Shows all details of the knowledge base Contoso, including tags, revision and path.

## PARAMETERS

### -Name
Name (wildcards allowed) or directory path of a knowledge base.
Lists all when omitted.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: *
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: True
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String. You can pipe objects with a Name property.
## OUTPUTS

### MCPPosh.KnowledgeBase: Name, Description, Documents, Characters, Tags, Revision, Created, Updated and Path.
## NOTES

## RELATED LINKS

[https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Get-McpKnowledgeBase.md](https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Get-McpKnowledgeBase.md)

[New-McpKnowledgeBase]()

[Set-McpKnowledgeBase]()

[Remove-McpKnowledgeBase]()

