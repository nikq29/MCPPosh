function Invoke-McpAddNoteTool {
    <#
    .SYNOPSIS
        Runs the MCP tool add_note.

    .DESCRIPTION
        Stores a Markdown note from the AI agent as a document of source type Agent with the tag agent-note. A note with the same title is updated. Only available when the server runs with -AllowWrite. A note has at most 20 tags of at most 50 characters. Limits keep agents from filling the knowledge base: at most 1000 agent notes and 10 million characters of agent notes per knowledge base, and at most 30 notes per minute per server. Documents added by people do not count.

    .PARAMETER Context
        The server context created by New-McpServerContext.

    .PARAMETER Arguments
        The tool arguments with title, content and optional tags.

    .EXAMPLE
        Invoke-McpAddNoteTool -Context $context -Arguments ([ordered]@{ title = 'Printer'; content = 'Use driver v3.' })

        Saves the note and returns a tool result with its document id.
    #>
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
    # Tags are stored in the manifest and are not counted by the size limits below.
    if ($tags.Count -gt 20 -or @($tags | Where-Object { $_.Length -gt 50 }).Count -gt 0) { throw [System.ArgumentException]::new('A note may have at most 20 tags of at most 50 characters each.') }

    # Limits against agents (or clients) that fill the disk or keep the server busy rebuilding the index.
    # The messages are written for the model: they are returned as tool errors.
    $now = [datetime]::UtcNow
    $recentWrites = $Context.NoteWriteTimes
    while ($recentWrites.Count -gt 0 -and ($now - $recentWrites.Peek()).TotalSeconds -ge 60) { $null = $recentWrites.Dequeue() }
    if ($recentWrites.Count -ge $script:McpMaxNotesPerMinute) {
        throw [System.ArgumentException]::new("Too many notes: this server accepts at most $($script:McpMaxNotesPerMinute) notes per minute. Try again later.")
    }

    $index = Update-McpServerIndex -Context $Context
    $agentNotes = @($index.Documents.Values | Where-Object { $_.sourceType -eq 'Agent' })
    # Same match as Save-McpDocument: a note with the same title is replaced instead of added.
    $existing = $agentNotes | Where-Object { $_.title -eq $title } | Select-Object -First 1
    if (-not $existing -and $agentNotes.Count -ge $script:McpMaxAgentNotes) {
        throw [System.ArgumentException]::new("The knowledge base already contains the maximum of $($script:McpMaxAgentNotes) agent notes. Update an existing note by using its title, or ask a person to review and remove old notes.")
    }
    $storedChars = 0L
    foreach ($note in $agentNotes) { $storedChars += [long]$note.chars }
    if ($existing) { $storedChars -= [long]$existing.chars }
    if ($storedChars + $content.Length -gt $script:McpMaxAgentNoteChars) {
        throw [System.ArgumentException]::new("The agent notes of this knowledge base must not exceed $($script:McpMaxAgentNoteChars) characters in total ($storedChars are used). Shorten the note, update an existing note, or ask a person to review and remove old notes.")
    }
    $recentWrites.Enqueue($now)

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
