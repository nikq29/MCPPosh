---
external help file: MCPPosh-help.xml
GeneratedBy: Sampler update_help_source task
Module Name: MCPPosh
online version: https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Update-McpDocument.md
schema: 2.0.0
---

# Update-McpDocument

## SYNOPSIS
Re-imports file and URL documents from their original source when the source changed.

## SYNTAX

### Id (Default)
```
Update-McpDocument [-Id] <String[]> [-Force] [-RemoveMissing] [-KnowledgeBase <String>]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

### All
```
Update-McpDocument [-All] [-Force] [-RemoveMissing] [-KnowledgeBase <String>]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
For file documents the source file hash is compared; URL documents are downloaded again.
Inline documents and agent notes have no source and are skipped.
Use -Force to re-import
even unchanged sources (e.g.
after installing PDF support or registering a converter).

## EXAMPLES

### EXAMPLE 1
```
Update-McpDocument -All -KnowledgeBase Contoso
```

Re-imports every file and URL document of the knowledge base Contoso whose source changed.

### EXAMPLE 2
```
Get-McpDocument -SourceType Url | Update-McpDocument -Force
```

Downloads and converts all web documents of the knowledge base Default again, even if they did not change.

### EXAMPLE 3
```
Update-McpDocument -All -RemoveMissing
```

Updates all documents and removes documents whose source file no longer exists.

## PARAMETERS

### -Id
Documents to update.
Use -All to update every document.

```yaml
Type: String[]
Parameter Sets: Id
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -All
Updates every document of the knowledge base instead of the documents named with -Id.

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

### -Force
Re-imports documents even when the source has not changed, for example after installing PDF support.

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

### -RemoveMissing
Remove file documents whose source file no longer exists.

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

### MCPPosh.Document: Id, Title, Format, Tags, SourceType (File, Url, Inline or Agent), Source, Summary, Chars, Added, Updated, KnowledgeBase, Uri and, with -IncludeContent, Content. Only documents that were re-imported are returned.
## NOTES

## RELATED LINKS

[https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Update-McpDocument.md](https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Update-McpDocument.md)

[Add-McpDocument]()

[Get-McpDocument]()

