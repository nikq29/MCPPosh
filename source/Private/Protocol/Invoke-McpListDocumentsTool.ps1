function Invoke-McpListDocumentsTool {
    <#
    .SYNOPSIS
        Runs the MCP tool list_documents.

    .DESCRIPTION
        Lists the documents of the knowledge base with id, title, tags, format and summary, optionally filtered by tag and paged with limit and offset.

    .PARAMETER Context
        The server context created by New-McpServerContext.

    .PARAMETER Arguments
        The tool arguments with optional tag, limit and offset.

    .EXAMPLE
        Invoke-McpListDocumentsTool -Context $context -Arguments ([ordered]@{ tag = 'runbook' })

        Lists all documents with the tag runbook.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Context,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Arguments
    )

    $tag = Get-McpArgument -Arguments $Arguments -Name 'tag'
    $limit = Get-McpArgument -Arguments $Arguments -Name 'limit' -Type Integer -Default 100 -Minimum 1 -Maximum 500
    $offset = Get-McpArgument -Arguments $Arguments -Name 'offset' -Type Integer -Default 0 -Minimum 0

    $index = Update-McpServerIndex -Context $Context
    $documents = @($index.Documents.Values | Sort-Object -Property { $_.title })
    if ($tag) {
        $documents = @($documents | Where-Object { @($_.tags) -contains $tag })
    }
    $total = $documents.Count
    $page = @($documents | Select-Object -Skip $offset -First $limit)

    $kbName = $Context.KnowledgeBase.Name
    $builder = [System.Text.StringBuilder]::new()
    $filterText = if ($tag) { " with tag '$tag'" } else { '' }
    $null = $builder.AppendLine("Knowledge base '$kbName': $total document(s)$filterText.")
    $structured = [System.Collections.Generic.List[object]]::new()
    foreach ($doc in $page) {
        $tagText = if (@($doc.tags).Count -gt 0) { " [tags: $(@($doc.tags) -join ', ')]" } else { '' }
        $summary = if ($doc.summary) { " - $($doc.summary)" } else { '' }
        $null = $builder.AppendLine("- $($doc.title) (id: $($doc.id))$tagText$summary")
        $structured.Add([ordered]@{
                id      = [string]$doc.id
                title   = [string]$doc.title
                tags    = [string[]]@($doc.tags | Where-Object { $_ })
                format  = [string]$doc.format
                summary = [string]$doc.summary
                updated = [string]$doc.updated
            })
    }
    if ($offset + $page.Count -lt $total) {
        $null = $builder.Append("[Showing $($offset + 1)-$($offset + $page.Count) of $total. Call list_documents with offset=$($offset + $page.Count) for more.]")
    }

    New-McpToolResult -Text $builder.ToString().TrimEnd() -Structured ([ordered]@{
            total     = $total
            offset    = $offset
            documents = $structured.ToArray()
        })
}
