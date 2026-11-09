function Get-McpToolList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Context
    )

    $kb = $Context.KnowledgeBase
    $about = if ($kb.Description) { " ($($kb.Description))" } else { '' }

    $tools = [System.Collections.Generic.List[object]]::new()
    $tools.Add([ordered]@{
            name        = 'search_documentation'
            title       = 'Search documentation'
            description = "Search the '$($kb.Name)' documentation knowledge base$about. Returns the most relevant sections with their document ids. Use specific keywords or a short question. Call get_document to read a complete document."
            inputSchema = [ordered]@{
                type       = 'object'
                properties = [ordered]@{
                    query = [ordered]@{ type = 'string'; description = 'Search terms or a short natural-language question.' }
                    limit = [ordered]@{ type = 'integer'; description = 'Maximum number of sections to return (1-20, default 5).'; minimum = 1; maximum = 20; default = 5 }
                    tags  = [ordered]@{ type = 'array'; items = [ordered]@{ type = 'string' }; description = 'Only search documents that have at least one of these tags.' }
                }
                required   = @('query')
            }
            annotations = [ordered]@{ readOnlyHint = $true; openWorldHint = $false }
        })
    $tools.Add([ordered]@{
            name        = 'get_document'
            title       = 'Read document'
            description = "Read a complete document from the '$($kb.Name)' knowledge base as Markdown. Long documents are returned in pages; use offset to continue."
            inputSchema = [ordered]@{
                type       = 'object'
                properties = [ordered]@{
                    id       = [ordered]@{ type = 'string'; description = 'Document id as returned by search_documentation or list_documents.' }
                    offset   = [ordered]@{ type = 'integer'; description = 'Character offset to start reading from (default 0).'; minimum = 0; default = 0 }
                    maxChars = [ordered]@{ type = 'integer'; description = 'Maximum number of characters to return (500-100000, default 20000).'; minimum = 500; maximum = 100000; default = 20000 }
                }
                required   = @('id')
            }
            annotations = [ordered]@{ readOnlyHint = $true; openWorldHint = $false }
        })
    $tools.Add([ordered]@{
            name        = 'list_documents'
            title       = 'List documents'
            description = "List the documents in the '$($kb.Name)' knowledge base with id, title, tags and a short summary."
            inputSchema = [ordered]@{
                type       = 'object'
                properties = [ordered]@{
                    tag    = [ordered]@{ type = 'string'; description = 'Only list documents with this tag.' }
                    limit  = [ordered]@{ type = 'integer'; description = 'Maximum number of documents (1-500, default 100).'; minimum = 1; maximum = 500; default = 100 }
                    offset = [ordered]@{ type = 'integer'; description = 'Number of documents to skip (default 0).'; minimum = 0; default = 0 }
                }
            }
            annotations = [ordered]@{ readOnlyHint = $true; openWorldHint = $false }
        })
    if ($Context.AllowWrite) {
        $tools.Add([ordered]@{
                name        = 'add_note'
                title       = 'Add note'
                description = "Save a note (Markdown) in the '$($kb.Name)' knowledge base, e.g. a finding, decision or correction. A note with the same title is updated."
                inputSchema = [ordered]@{
                    type       = 'object'
                    properties = [ordered]@{
                        title   = [ordered]@{ type = 'string'; description = 'Short, descriptive title.' }
                        content = [ordered]@{ type = 'string'; description = 'Note content in Markdown.' }
                        tags    = [ordered]@{ type = 'array'; items = [ordered]@{ type = 'string' }; description = 'Optional tags.' }
                    }
                    required   = @('title', 'content')
                }
                annotations = [ordered]@{ readOnlyHint = $false; destructiveHint = $false; idempotentHint = $true; openWorldHint = $false }
            })
    }

    [ordered]@{ tools = $tools.ToArray() }
}

function New-McpToolResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Text,

        [object] $Structured,

        [switch] $IsError
    )

    $result = [ordered]@{
        content = @([ordered]@{ type = 'text'; text = $Text })
    }
    if ($null -ne $Structured) { $result['structuredContent'] = $Structured }
    if ($IsError) { $result['isError'] = $true }
    $result
}

function Invoke-McpToolCall {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Context,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Params
    )

    $name = $Params['name']
    if ($name -isnot [string] -or -not $name) {
        throw (New-McpRpcError -Code -32602 -Message 'Invalid params: tool name is required')
    }
    $arguments = $Params['arguments']
    if ($null -eq $arguments) { $arguments = [ordered]@{} }
    if ($arguments -isnot [System.Collections.IDictionary]) {
        throw (New-McpRpcError -Code -32602 -Message 'Invalid params: arguments must be an object')
    }

    $known = @('search_documentation', 'get_document', 'list_documents')
    if ($Context.AllowWrite) { $known += 'add_note' }
    if ($known -notcontains $name) {
        throw (New-McpRpcError -Code -32602 -Message "Unknown tool: $name")
    }

    try {
        switch ($name) {
            'search_documentation' { Invoke-McpSearchTool -Context $Context -Arguments $arguments }
            'get_document' { Invoke-McpGetDocumentTool -Context $Context -Arguments $arguments }
            'list_documents' { Invoke-McpListDocumentsTool -Context $Context -Arguments $arguments }
            'add_note' { Invoke-McpAddNoteTool -Context $Context -Arguments $arguments }
        }
    }
    catch {
        # Tool execution errors are reported to the model (isError) so it can correct itself.
        Write-McpLog -Context $Context -Level WARN -Message "Tool $name failed: $($_.Exception.Message)"
        New-McpToolResult -Text "Error: $($_.Exception.Message)" -IsError
    }
}

function Invoke-McpSearchTool {
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

function Invoke-McpListDocumentsTool {
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

function Invoke-McpAddNoteTool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Context,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Arguments
    )

    $title = Get-McpArgument -Arguments $Arguments -Name 'title' -Required
    $content = Get-McpArgument -Arguments $Arguments -Name 'content' -Required
    $tags = Get-McpArgument -Arguments $Arguments -Name 'tags' -Type StringArray -Default @()
    if ($title.Length -gt 200) { throw [System.ArgumentException]::new('The title must not exceed 200 characters.') }
    if ($content.Length -gt 200000) { throw [System.ArgumentException]::new('The content must not exceed 200000 characters.') }

    $allTags = @($tags) + @('agent-note')
    $saved = Save-McpDocument -KnowledgeBase $Context.KnowledgeBase -Content $content -Title $title -Format Markdown -SourceType Agent -Tags $allTags
    $null = Update-McpServerIndex -Context $Context -Force
    $state = if ($saved.Created) { 'Saved new note' } elseif ($saved.Changed) { 'Updated note' } else { 'Note unchanged' }
    Write-McpLog -Context $Context -Message ("add_note: {0} '{1}' ({2})" -f $state, $title, $saved.Record.id)
    New-McpToolResult -Text "$state '$title' (document id: $($saved.Record.id))." -Structured ([ordered]@{
            id      = [string]$saved.Record.id
            created = [bool]$saved.Created
            changed = [bool]$saved.Changed
        })
}
