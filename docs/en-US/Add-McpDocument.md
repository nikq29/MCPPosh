---
external help file: MCPPosh-help.xml
GeneratedBy: Sampler update_help_source task
Module Name: MCPPosh
online version: https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Add-McpDocument.md
schema: 2.0.0
---

# Add-McpDocument

## SYNOPSIS
Adds knowledge to a knowledge base: files, folders, web pages or inline text.

## SYNTAX

### Path (Default)
```
Add-McpDocument [-Path] <String[]> [-Recurse] [-Include <String[]>] [-Exclude <String[]>] [-Title <String>]
 [-Tags <String[]>] [-Format <String>] [-KnowledgeBase <String>] [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

### Url
```
Add-McpDocument -Url <Uri[]> [-Title <String>] [-Tags <String[]>] [-Format <String>] [-KnowledgeBase <String>]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

### Content
```
Add-McpDocument -Content <String> -Title <String> [-Tags <String[]>] [-Format <String>]
 [-KnowledgeBase <String>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Files are converted to Markdown when they are added.
Supported out of the box:
Markdown, text, HTML, Word (.docx), PDF (with PSWritePDF or pdftotext), CSV/TSV,
JSON, YAML, XML and source code.
Register additional formats with
Register-McpDocumentConverter.

Adding the same file or URL again updates the existing document instead of creating a
duplicate.
Inline content (-Content) is matched by its title.
Running MCP servers pick up
changes automatically.

## EXAMPLES

### EXAMPLE 1
```
Add-McpDocument -Path .\docs -Recurse -Include *.md, *.docx -Tags handbook
```

Imports all Markdown and Word files below .\docs into the knowledge base Default and tags them with handbook.
Files that were imported before are updated instead of duplicated.

### EXAMPLE 2
```
Get-ChildItem C:\Wiki -Filter *.html -Recurse | Add-McpDocument -KnowledgeBase Contoso
```

Pipes HTML files from Get-ChildItem into the knowledge base Contoso.
Navigation, scripts and styles are removed; headings, lists, tables and code blocks are kept.

### EXAMPLE 3
```
Add-McpDocument -Url https://learn.microsoft.com/powershell/scripting/overview -Tags powershell
```

Downloads a web page, converts it to Markdown and stores the URL as source, so Update-McpDocument can refresh it later.

### EXAMPLE 4
```
Add-McpDocument -Title 'VPN troubleshooting' -Content 'Restart the agent with: Restart-Service vpnagent' -Tags vpn, runbook
```

Stores a short note as a document.
Running the command again with the same title updates the note.

## PARAMETERS

### -Path
Files or folders to import.
Wildcards are supported, and Get-ChildItem output can be piped in.

```yaml
Type: String[]
Parameter Sets: Path
Aliases: FullName, PSPath, LiteralPath

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: True
```

### -Recurse
Import folders recursively.

```yaml
Type: SwitchParameter
Parameter Sets: Path
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Include
Only import files whose name matches one of these wildcard patterns (e.g.
*.md, *.docx).

```yaml
Type: String[]
Parameter Sets: Path
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Exclude
Skip files whose name matches one of these wildcard patterns.

```yaml
Type: String[]
Parameter Sets: Path
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Url
Web pages or online documents (HTML, Markdown, PDF, Word, JSON ...) to import.

```yaml
Type: Uri[]
Parameter Sets: Url
Aliases: Uri

Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Content
Text to store as a document, e.g.
a note or a snippet.
Requires -Title.

```yaml
Type: String
Parameter Sets: Content
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Title
Document title.
Defaults to the title found in the document (front matter, first heading,
HTML \<title\>, Word title) or the file name.

```yaml
Type: String
Parameter Sets: Path, Url
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

```yaml
Type: String
Parameter Sets: Content
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Tags
Tags for filtering, e.g.
'runbook', 'api'.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -Format
Force a converter (e.g.
Markdown, Text, Html, Docx, Pdf, Csv, Json, Yaml, Xml, Code or a
custom converter name) instead of detecting it from the file extension or content type.

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
Name or path of the knowledge base.
'Default' is created automatically.

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

### System.String, System.IO.FileInfo. You can pipe paths or file objects from Get-ChildItem, and objects with a Url or Uri property.
## OUTPUTS

### MCPPosh.Document: Id, Title, Format, Tags, SourceType (File, Url, Inline or Agent), Source, Summary, Chars, Added, Updated, KnowledgeBase, Uri and, with -IncludeContent, Content.
## NOTES

## RELATED LINKS

[https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Add-McpDocument.md](https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Add-McpDocument.md)

[Get-McpDocument]()

[Update-McpDocument]()

[Register-McpDocumentConverter]()

[Search-McpDocument]()

