function Invoke-McpGetDocumentTool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Context,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Arguments
    )

    $id = Get-McpArgument -Arguments $Arguments -Name 'id' -Required
    $offset = Get-McpArgument -Arguments $Arguments -Name 'offset' -Type Integer -Default 0 -Minimum 0
    $maxChars = Get-McpArgument -Arguments $Arguments -Name 'maxChars' -Type Integer -Default 20000 -Minimum 500 -Maximum 100000

    $index = Update-McpServerIndex -Context $Context
    $record = $index.Documents[$id]
    if (-not $record) {
        throw [System.ArgumentException]::new("Document '$id' was not found. Use search_documentation or list_documents to find valid ids.")
    }
    $content = Get-McpDocumentContent -KbPath $Context.KnowledgeBase.Path -Id $id
    if ($null -eq $content) {
        throw [System.ArgumentException]::new("The content of document '$id' is missing.")
    }

    $total = $content.Length
    if ($offset -gt $total) { $offset = $total }
    $length = [Math]::Min($maxChars, $total - $offset)
    $slice = $content.Substring($offset, $length)
    $end = $offset + $length

    $builder = [System.Text.StringBuilder]::new()
    $null = $builder.AppendLine("Document: $($record.title)")
    $null = $builder.AppendLine("id: $id | format: $($record.format) | updated: $($record.updated)")
    if ($record.source) { $null = $builder.AppendLine("source: $($record.source)") }
    if (@($record.tags).Count -gt 0) { $null = $builder.AppendLine("tags: $(@($record.tags) -join ', ')") }
    $null = $builder.AppendLine()
    $null = $builder.Append($slice)
    if ($end -lt $total) {
        $null = $builder.AppendLine()
        $null = $builder.AppendLine()
        $null = $builder.Append("[Showing characters $offset-$end of $total. Call get_document with offset=$end to continue.]")
    }

    New-McpToolResult -Text $builder.ToString() -Structured ([ordered]@{
            id        = $id
            title     = [string]$record.title
            format    = [string]$record.format
            source    = $record.source
            tags      = [string[]]@($record.tags | Where-Object { $_ })
            offset    = $offset
            length    = $length
            total     = $total
            truncated = ($end -lt $total)
            content   = $slice
        })
}
