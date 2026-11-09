function ConvertTo-McpKnowledgeBaseObject {
    <#
    .SYNOPSIS
        Converts a resolved knowledge base to a summary object.

    .DESCRIPTION
        Reads the manifest of a knowledge base and returns an MCPPosh.KnowledgeBase object with name, description, number of documents, total characters, tags, revision and timestamps.

    .PARAMETER KnowledgeBase
        The resolved knowledge base (see Resolve-McpKnowledgeBase) to summarize.

    .EXAMPLE
        ConvertTo-McpKnowledgeBaseObject -KnowledgeBase (Resolve-McpKnowledgeBase -KnowledgeBase Contoso)

        Returns the summary of the knowledge base Contoso.
    #>
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
