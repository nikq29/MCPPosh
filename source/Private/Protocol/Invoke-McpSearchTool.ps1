function Invoke-McpSearchTool {
    <#
    .SYNOPSIS
        Runs the MCP tool search_documentation.

    .DESCRIPTION
        Searches the knowledge base with BM25 and returns the best matching sections as Markdown text plus structured content with document ids, titles, headings, scores, tags and resource URIs.

    .PARAMETER Context
        The server context created by New-McpServerContext.

    .PARAMETER Arguments
        The tool arguments with query and optional limit and tags.

    .EXAMPLE
        Invoke-McpSearchTool -Context $context -Arguments ([ordered]@{ query = 'vpn restart'; limit = 3 })

        Returns up to three matching sections.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Context,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Arguments
    )

    $query = Get-McpArgument -Arguments $Arguments -Name 'query' -Required
    $limit = Get-McpArgument -Arguments $Arguments -Name 'limit' -Type Integer -Default 5 -Minimum 1 -Maximum 20
    $tags = Get-McpArgument -Arguments $Arguments -Name 'tags' -Type StringArray -Default @()

    $index = Update-McpServerIndex -Context $Context
    $results = @(Invoke-McpSearch -Index $index -Query $query -Top $limit -Tags $tags)
    Write-McpLog -Context $Context -Message ('search "{0}" -> {1} result(s)' -f $query, $results.Count)

    $kbName = $Context.KnowledgeBase.Name
    if ($results.Count -eq 0) {
        $hint = if ($index.Documents.Count -eq 0) { "The knowledge base '$kbName' is empty." } else { 'Try other or fewer keywords, or call list_documents to browse.' }
        return New-McpToolResult -Text "No matching sections found for `"$query`". $hint" -Structured ([ordered]@{ results = @() })
    }

    $builder = [System.Text.StringBuilder]::new()
    $null = $builder.AppendLine("Found $($results.Count) section(s) in knowledge base '$kbName' for `"$query`":")
    $structured = [System.Collections.Generic.List[object]]::new()
    $position = 0
    foreach ($result in $results) {
        $position++
        $location = if ($result.Heading -and $result.Heading -ne $result.Title) { "$($result.Title) > $($result.Heading)" } else { $result.Title }
        $tagText = if ($result.Tags.Count -gt 0) { " | tags: $($result.Tags -join ', ')" } else { '' }
        $null = $builder.AppendLine()
        $null = $builder.AppendLine("## $position. $location")
        $null = $builder.AppendLine("document id: $($result.DocumentId) | score: $($result.Score)$tagText")
        $null = $builder.AppendLine()
        $null = $builder.AppendLine($result.Text)
        $structured.Add([ordered]@{
                documentId = $result.DocumentId
                title      = $result.Title
                heading    = $result.Heading
                score      = $result.Score
                tags       = $result.Tags
                uri        = ('mcpposh://{0}/documents/{1}' -f $kbName, $result.DocumentId)
                text       = $result.Text
            })
    }
    $null = $builder.AppendLine()
    $null = $builder.Append('Call get_document with a document id to read the complete document.')
    New-McpToolResult -Text $builder.ToString() -Structured ([ordered]@{ results = $structured.ToArray() })
}
