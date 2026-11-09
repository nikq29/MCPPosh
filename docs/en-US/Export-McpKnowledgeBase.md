---
external help file: MCPPosh-help.xml
GeneratedBy: Sampler update_help_source task
Module Name: MCPPosh
online version: https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Export-McpKnowledgeBase.md
schema: 2.0.0
---

# Export-McpKnowledgeBase

## SYNOPSIS
Exports a knowledge base to a ZIP archive (backup or transfer to another machine).

## SYNTAX

```
Export-McpKnowledgeBase [-Name] <String> [-DestinationPath] <String> [-Force]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
The archive contains the knowledge base metadata, manifest, documents and search index.
Logs and lock files are not included.
Restore it with Import-McpKnowledgeBase.

## EXAMPLES

### EXAMPLE 1
```
Export-McpKnowledgeBase -Name Contoso -DestinationPath .\contoso-kb.zip
```

Creates a ZIP archive with the metadata, documents and search index of the knowledge base Contoso, for example as a backup.

### EXAMPLE 2
```
Get-McpKnowledgeBase | ForEach-Object { Export-McpKnowledgeBase -Name $_.Name -DestinationPath "./backup/$($_.Name).zip" -Force }
```

Backs up every knowledge base into its own archive and overwrites older backups.

## PARAMETERS

### -Name
Name or directory path of the knowledge base to export.
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

### -DestinationPath
Path of the ZIP archive to create.
Relative paths are resolved against the current location.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Force
Overwrites an existing archive at the destination path.

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

### System.IO.FileInfo. The created ZIP archive.
## NOTES

## RELATED LINKS

[https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Export-McpKnowledgeBase.md](https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Export-McpKnowledgeBase.md)

[Import-McpKnowledgeBase]()

[Publish-McpKnowledgeBase]()

