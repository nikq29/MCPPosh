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
