---
external help file: MCPPosh-help.xml
GeneratedBy: Sampler update_help_source task
Module Name: MCPPosh
online version: https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/New-McpKnowledgeBase.md
schema: 2.0.0
---

# New-McpKnowledgeBase

## SYNOPSIS
Creates a new knowledge base for documentation that an MCP server can serve.

## SYNTAX

```
New-McpKnowledgeBase [-Name] <String> [[-Description] <String>] [-Path <String>]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
A knowledge base is a folder that holds normalized Markdown documents, a manifest and a
search index.
By default it is created below $env:MCPPOSH_HOME (or ~/.mcpposh).
Use -Path
to place it somewhere else, e.g.
on a mounted Azure Files share.

The description is sent to the AI agent as server instructions and in the tool
descriptions, so describe what the documentation covers and when the agent should use it.

## EXAMPLES

### EXAMPLE 1
```
New-McpKnowledgeBase -Name Contoso -Description 'Internal documentation for the Contoso platform: architecture, runbooks and coding guidelines.'
```

Creates the knowledge base Contoso.
The description tells AI agents what the documentation covers and when to use it.

### EXAMPLE 2
```
New-McpKnowledgeBase -Name Shared -Path Z:\mcpposh\Shared
```

Creates a knowledge base on a mapped network drive.
Pass the path to -KnowledgeBase of the other cmdlets to work with it.

## PARAMETERS

### -Name
Name of the knowledge base (letters, digits, '.', '_' and '-').

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Description
What the documentation is about.
Shown to the AI agent.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Path
Optional directory for the knowledge base.
Defaults to $env:MCPPOSH_HOME/knowledgebases/\<Name\>.

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

### MCPPosh.KnowledgeBase: Name, Description, Documents, Characters, Tags, Revision, Created, Updated and Path.
## NOTES

## RELATED LINKS

[https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/New-McpKnowledgeBase.md](https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/New-McpKnowledgeBase.md)

[Get-McpKnowledgeBase]()

[Set-McpKnowledgeBase]()

[Add-McpDocument]()

