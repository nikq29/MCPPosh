---
external help file: MCPPosh-help.xml
GeneratedBy: Sampler update_help_source task
Module Name: MCPPosh
online version: https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Import-McpKnowledgeBase.md
schema: 2.0.0
---

# Import-McpKnowledgeBase

## SYNOPSIS
Imports a knowledge base from a ZIP archive created by Export-McpKnowledgeBase.

## SYNTAX

```
Import-McpKnowledgeBase [-Path] <String> [-Name <String>] [-Force]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Restores a knowledge base from a ZIP archive created by Export-McpKnowledgeBase, optionally under a new name.
Only knowledge base files are extracted and paths are validated. Archives with invalid document ids, more than 100000 entries or more than 1 GB of uncompressed content are rejected.

## EXAMPLES

### EXAMPLE 1
```
Import-McpKnowledgeBase -Path .\contoso-kb.zip
```

Restores the knowledge base from the archive under the name stored in the archive.

### EXAMPLE 2
```
Import-McpKnowledgeBase -Path .\contoso-kb.zip -Name ContosoTest
```

Imports the archive as a new knowledge base ContosoTest, for example to test changes.

## PARAMETERS

### -Path
Path of the ZIP archive created by Export-McpKnowledgeBase.
Accepts the FullName property of files through the pipeline.

```yaml
Type: String
Parameter Sets: (All)
Aliases: FullName

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Name
Name for the imported knowledge base.
Defaults to the name stored in the archive.

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

### -Force
Replace an existing knowledge base with the same name.

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

### System.String. You can pipe file objects; their FullName property binds to -Path.
## OUTPUTS

### MCPPosh.KnowledgeBase: Name, Description, Documents, Characters, Tags, Revision, Created, Updated and Path.
## NOTES

## RELATED LINKS

[https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Import-McpKnowledgeBase.md](https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Import-McpKnowledgeBase.md)

[Export-McpKnowledgeBase]()

[Get-McpKnowledgeBase]()

