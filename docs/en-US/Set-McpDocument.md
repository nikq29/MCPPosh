---
external help file: MCPPosh-help.xml
GeneratedBy: Sampler update_help_source task
Module Name: MCPPosh
online version: https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Set-McpDocument.md
schema: 2.0.0
---

# Set-McpDocument

## SYNOPSIS
Changes the title, tags or content of a document.

## SYNTAX

```
Set-McpDocument [-Id] <String> [-Title <String>] [-Tags <String[]>] [-AddTags <String[]>]
 [-RemoveTags <String[]>] [-Content <String>] [-KnowledgeBase <String>] [-PassThru]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Changes the title, the tags or the Markdown content of an existing document and refreshes its search index.
Use -AddTags and -RemoveTags to edit tags incrementally.

## EXAMPLES

### EXAMPLE 1
```
Set-McpDocument -Id vpn-troubleshooting-1a2b3c -AddTags network
```

Adds the tag network to a document of the knowledge base Default.

### EXAMPLE 2
```
Get-McpDocument -Tag draft | Set-McpDocument -RemoveTags draft -AddTags reviewed
```

Replaces the tag draft with reviewed on all draft documents.

### EXAMPLE 3
```
Set-McpDocument -Id vpn-troubleshooting-1a2b3c -Title 'VPN: troubleshooting guide' -PassThru
```

Renames a document and returns the updated document.

## PARAMETERS

### -Id
Id of the document to change.
Accepts the Id property of objects from Get-McpDocument through the pipeline.

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

### -Title
New title of the document.
The title is also indexed for the search.

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

### -Tags
Replaces all tags of the document with these tags.
Pass an empty array to remove all tags.

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

### -AddTags
Tags to add to the existing tags of the document.

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

### -RemoveTags
Tags to remove from the existing tags of the document.

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

### -Content
Replaces the Markdown content.
Note that Update-McpDocument re-imports file and URL
documents from their source and would overwrite manual content changes.

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

### -KnowledgeBase
Name or directory path of the knowledge base that contains the document.
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

### -PassThru
Returns the updated document object.
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

### MCPPosh.Document. You can pipe documents from Get-McpDocument; Id and KnowledgeBase bind by property name.
## OUTPUTS

### None by default. With -PassThru: MCPPosh.Document: Id, Title, Format, Tags, SourceType (File, Url, Inline or Agent), Source, Summary, Chars, Added, Updated, KnowledgeBase, Uri and, with -IncludeContent, Content.
## NOTES

## RELATED LINKS

[https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Set-McpDocument.md](https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Set-McpDocument.md)

[Get-McpDocument]()

[Update-McpDocument]()

