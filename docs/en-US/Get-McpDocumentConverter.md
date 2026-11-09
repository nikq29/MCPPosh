---
external help file: MCPPosh-help.xml
GeneratedBy: Sampler update_help_source task
Module Name: MCPPosh
online version: https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Get-McpDocumentConverter.md
schema: 2.0.0
---

# Get-McpDocumentConverter

## SYNOPSIS
Lists the available document converters (formats) and their file extensions.

## SYNTAX

```
Get-McpDocumentConverter [[-Name] <String>] [-Extension <String>]
 [<CommonParameters>]
```

## DESCRIPTION
Lists the built-in and custom document converters that Add-McpDocument uses to turn files into Markdown, together with the file extensions each converter handles.

## EXAMPLES

### EXAMPLE 1
```
Get-McpDocumentConverter
```

Lists all built-in and custom converters with the file extensions they handle.

### EXAMPLE 2
```
Get-McpDocumentConverter -Extension .docx
```

Shows which converter imports Word documents.

## PARAMETERS

### -Name
Name of the converter to return.
Wildcards are supported; all converters are returned by default.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: *
Accept pipeline input: False
Accept wildcard characters: True
```

### -Extension
Only return the converter that handles this file extension, for example .docx or docx.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None. You cannot pipe objects to this cmdlet.
## OUTPUTS

### MCPPosh.Converter: Name, Extensions, ScriptBlock and Builtin.
## NOTES

## RELATED LINKS

[https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Get-McpDocumentConverter.md](https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Get-McpDocumentConverter.md)

[Register-McpDocumentConverter]()

[Unregister-McpDocumentConverter]()

