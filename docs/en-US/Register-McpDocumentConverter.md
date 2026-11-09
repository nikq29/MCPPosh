---
external help file: MCPPosh-help.xml
GeneratedBy: Sampler update_help_source task
Module Name: MCPPosh
online version: https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Register-McpDocumentConverter.md
schema: 2.0.0
---

# Register-McpDocumentConverter

## SYNOPSIS
Registers a custom converter so Add-McpDocument can import additional file formats.

## SYNTAX

```
Register-McpDocumentConverter [-Name] <String> [-Extension] <String[]> [-ScriptBlock] <ScriptBlock> [-Force]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
The script block receives the file path and returns either a Markdown string or a
hashtable with Content (required), Title and Tags.
Custom converters take precedence
over built-in converters for the same extension.

Registrations last for the current PowerShell session; put them in your profile to make
them permanent.
Running servers do not need the converter: documents are converted when
they are added.

## EXAMPLES

### EXAMPLE 1
```
Register-McpDocumentConverter -Name Pptx -Extension .pptx -ScriptBlock {
    param($Path)
    # use a module of your choice to extract the slide text
    @{ Content = (Get-MySlideText -Path $Path) -join "`n`n"; Title = (Split-Path $Path -LeafBase) }
}
```

Adds support for PowerPoint files.
The script block returns a hashtable with the Markdown content and the title.

### EXAMPLE 2
```
Register-McpDocumentConverter -Name Email -Extension .eml -ScriptBlock { param($Path) Get-Content $Path -Raw }
```

Imports e-mail files as plain text.
Register converters in your profile to keep them for new sessions.

## PARAMETERS

### -Name
Name of the converter.
It is stored as the document format and can be passed to Add-McpDocument -Format.

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

### -Extension
One or more file extensions handled by the converter, with or without the leading dot (for example .eml).

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ScriptBlock
Script block that receives the file path and returns Markdown text or a hashtable with Content, Title and Tags.

```yaml
Type: ScriptBlock
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Force
Replaces an existing custom converter with the same name instead of failing.

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

### None. You cannot pipe objects to this cmdlet.
## OUTPUTS

### MCPPosh.Converter: Name, Extensions, ScriptBlock and Builtin.
## NOTES

## RELATED LINKS

[https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Register-McpDocumentConverter.md](https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Register-McpDocumentConverter.md)

[Get-McpDocumentConverter]()

[Unregister-McpDocumentConverter]()

[Add-McpDocument]()

