---
external help file: MCPPosh-help.xml
GeneratedBy: Sampler update_help_source task
Module Name: MCPPosh
online version: https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Search-McpDocument.md
schema: 2.0.0
---

# Search-McpDocument

## SYNOPSIS
Searches a knowledge base with the same BM25 search the AI agent uses.

## SYNTAX

```
Search-McpDocument [-Query] <String> [-Top <Int32>] [-Tag <String[]>] [-KnowledgeBase <String>]
 [<CommonParameters>]
```

## DESCRIPTION
Useful to check which sections an agent will find for a question before connecting it.

## EXAMPLES

### EXAMPLE 1
```
Search-McpDocument -Query 'restart the VPN connection' -KnowledgeBase Contoso
```

Returns the sections of the knowledge base Contoso that match the question best, exactly as the search_documentation tool would.

### EXAMPLE 2
```
Search-McpDocument 'deployment pipeline' -Top 3 | Format-List Title, Heading, Text
```

Shows the complete text of the three best matching sections.

### EXAMPLE 3
```
Search-McpDocument -Query 'certificate' -Tag vpn -KnowledgeBase Contoso
```

Only searches documents that have the tag vpn.

## PARAMETERS

### -Query
Search terms or a natural-language question.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -Top
Maximum number of results (sections).

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 5
Accept pipeline input: False
Accept wildcard characters: False
```

### -Tag
Only search documents that have at least one of these tags.

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

### -KnowledgeBase
Name or directory path of the knowledge base to search.
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

### System.String. You can pipe search queries.
## OUTPUTS

### MCPPosh.SearchResult: Score, DocumentId, Title, Heading, Tags, Source, Snippet and Text (the complete section).
## NOTES

## RELATED LINKS

[https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Search-McpDocument.md](https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Search-McpDocument.md)

[Get-McpDocument]()

[Add-McpDocument]()

[Start-McpServer]()

