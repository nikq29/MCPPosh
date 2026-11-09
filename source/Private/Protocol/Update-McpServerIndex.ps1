function Update-McpServerIndex {
    <#
    .SYNOPSIS
        Reloads knowledge base metadata and the search index when the manifest changed.
        Checks the file system at most once per second.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Context,

        [switch] $Force
    )

    $now = [datetime]::UtcNow
    if (-not $Force -and $null -ne $Context.Index -and ($now - $Context.LastIndexCheck).TotalMilliseconds -lt 1000) {
        return $Context.Index
    }
    $Context.LastIndexCheck = $now

    $previousStamp = if ($Context.Index) { $Context.Index.Stamp } else { $null }
    $index = Get-McpSearchIndex -KbPath $Context.KnowledgeBase.Path -Force:$Force
    if ($index.Stamp -ne $previousStamp) {
        $meta = Read-McpJsonFile -Path (Join-Path -Path $Context.KnowledgeBase.Path -ChildPath 'knowledgebase.json')
        if ($meta) { $Context.KnowledgeBase.Description = [string]$meta.description }
        if ($previousStamp) {
            Write-McpLog -Context $Context -Message ("Knowledge base reloaded: revision {0}, {1} documents, {2} chunks" -f $index.Revision, $index.Documents.Count, $index.Chunks.Count)
        }
    }
    $Context.Index = $index
    $index
}
