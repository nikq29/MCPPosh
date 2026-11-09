---
external help file: MCPPosh-help.xml
GeneratedBy: Sampler update_help_source task
Module Name: MCPPosh
online version: https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Unregister-McpDocumentConverter.md
schema: 2.0.0
---

# Unregister-McpDocumentConverter

## SYNOPSIS
Removes a custom document converter.
Built-in converters cannot be removed.

## SYNTAX

```
Unregister-McpDocumentConverter [-Name] <String> [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
Removes a custom converter that was registered with Register-McpDocumentConverter in the current session.
Built-in converters cannot be removed.

## EXAMPLES

### EXAMPLE 1
```
Unregister-McpDocumentConverter -Name Email
```

Removes the custom converter Email from the current session.

## PARAMETERS

### -Name
Name of the custom converter to remove.
Accepts the Name property of converter objects through the pipeline.

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

### MCPPosh.Converter. You can pipe converters from Get-McpDocumentConverter.
## OUTPUTS

### None.
## NOTES

## RELATED LINKS

[https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Unregister-McpDocumentConverter.md](https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Unregister-McpDocumentConverter.md)

[Register-McpDocumentConverter]()

[Get-McpDocumentConverter]()

