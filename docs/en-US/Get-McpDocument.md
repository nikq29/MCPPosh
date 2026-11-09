---
external help file: MCPPosh-help.xml
GeneratedBy: Sampler update_help_source task
Module Name: MCPPosh
online version: https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Get-McpDocument.md
schema: 2.0.0
---

# Get-McpDocument

## SYNOPSIS
Lists the documents of a knowledge base.

## SYNTAX

```
Get-McpDocument [[-Id] <String[]>] [-Title <String>] [-Tag <String[]>] [-Format <String[]>]
 [-SourceType <String[]>] [-IncludeContent] [-KnowledgeBase <String>]
 [<CommonParameters>]
```

## DESCRIPTION
Returns the documents stored in a knowledge base as MCPPosh.Document objects.
Filter by id, title, tag, format or source type, and add the Markdown content with -IncludeContent.

## EXAMPLES

### EXAMPLE 1
```
Get-McpDocument -KnowledgeBase Contoso -Tag runbook
```

Lists all documents of the knowledge base Contoso that have the tag runbook.

### EXAMPLE 2
```
Get-McpDocument -Title '*VPN*' -IncludeContent | Select-Object -ExpandProperty Content
```

Shows the Markdown content of all documents in the knowledge base Default whose title contains VPN.

### EXAMPLE 3
```
Get-McpDocument -KnowledgeBase Contoso -SourceType Agent
```

Lists the notes that AI agents stored with the add_note tool, so they can be reviewed.

## PARAMETERS

### -Id
Document ids (wildcards allowed).

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

### -Title
Filter by title (wildcards allowed).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: True
```

### -Tag
Only documents that have at least one of these tags.

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

### -Format
Only documents of these formats (Markdown, Html, Docx, ...).

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

### -SourceType
Only documents from these sources: File, Url, Inline or Agent (notes added by the AI agent).

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

### -IncludeContent
Adds the Markdown content as a Content property.

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

### -KnowledgeBase
Name or directory path of the knowledge base.
The knowledge base named Default is created automatically.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: Default
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String. You can pipe objects with an Id property.
## OUTPUTS

### MCPPosh.Document: Id, Title, Format, Tags, SourceType (File, Url, Inline or Agent), Source, Summary, Chars, Added, Updated, KnowledgeBase, Uri and, with -IncludeContent, Content.
## NOTES

## RELATED LINKS

[https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Get-McpDocument.md](https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Get-McpDocument.md)

[Add-McpDocument]()

[Set-McpDocument]()

[Remove-McpDocument]()

[Search-McpDocument]()

