function ConvertTo-McpKnowledgeBaseObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $KnowledgeBase
    )

    $manifest = Read-McpManifest -KbPath $KnowledgeBase.Path
    $documents = @($manifest['documents'])
    [pscustomobject]@{
        PSTypeName  = 'MCPPosh.KnowledgeBase'
        Name        = $KnowledgeBase.Name
        Description = $KnowledgeBase.Description
        Documents   = $documents.Count
        Characters  = [long](($documents | ForEach-Object { [long]$_.chars } | Measure-Object -Sum).Sum)
        Tags        = [string[]]@($documents | ForEach-Object { $_.tags } | Where-Object { $_ } | Sort-Object -Unique)
        Revision    = [long]$manifest['revision']
        Created     = ConvertTo-McpDateTime -Value $KnowledgeBase.Created
        Updated     = ConvertTo-McpDateTime -Value $manifest['updated']
        Path        = $KnowledgeBase.Path
    }
}
