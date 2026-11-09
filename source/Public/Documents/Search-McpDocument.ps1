function Search-McpDocument {
    <#
    .SYNOPSIS
        Searches a knowledge base with the same BM25 search the AI agent uses.

    .DESCRIPTION
        Useful to check which sections an agent will find for a question before connecting it.

    .PARAMETER Query
        Search terms or a natural-language question.

    .PARAMETER Top
        Maximum number of results (sections).

    .PARAMETER Tag
        Only search documents that have at least one of these tags.

    .PARAMETER KnowledgeBase
        Name or directory path of the knowledge base to search. The knowledge base named Default is created automatically.

    .EXAMPLE
        Search-McpDocument -Query 'restart the VPN connection' -KnowledgeBase Contoso

    .EXAMPLE
        Search-McpDocument 'deployment pipeline' -Top 3 | Format-List Title, Heading, Text
    #>
    [CmdletBinding()]
    [OutputType('MCPPosh.SearchResult')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string] $Query,

        [ValidateRange(1, 100)]
        [int] $Top = 5,

        [string[]] $Tag,

        [string] $KnowledgeBase = 'Default'
    )

    begin {
        $kb = Resolve-McpKnowledgeBase -KnowledgeBase $KnowledgeBase -CreateIfMissing:($KnowledgeBase -eq 'Default')
    }

    process {
        $index = Get-McpSearchIndex -KbPath $kb.Path
        Invoke-McpSearch -Index $index -Query $Query -Top $Top -Tags $Tag
    }
}
