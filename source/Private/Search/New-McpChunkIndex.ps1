function New-McpChunkIndex {
    <#
    .SYNOPSIS
        Chunks a document and pre-computes the term frequencies used by the BM25 search.

    .DESCRIPTION
        Splits a document into heading-aware chunks with Split-McpMarkdownSection and computes their term frequencies for the BM25 search. Heading terms count twice and title terms are added to every chunk.

    .PARAMETER Content
        The normalized Markdown content of the document.

    .PARAMETER Title
        Title of the document; its terms are added to every chunk.

    .EXAMPLE
        New-McpChunkIndex -Content "# VPN

        Restart the agent." -Title 'VPN'

        Returns one chunk with heading VPN, its text, length and term frequencies.
    #>
    [CmdletBinding()]
    [OutputType([object[]], [System.Array])]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Computes an in-memory index only; no system state is changed.')]
    param(
        [AllowEmptyString()]
        [string] $Content,

        [AllowEmptyString()]
        [string] $Title = ''
    )

    $titleTokens = Get-McpToken -Text $Title
    $chunks = [System.Collections.Generic.List[object]]::new()
    foreach ($section in (Split-McpMarkdownSection -Content $Content)) {
        $tf = @{}
        $length = 0
        foreach ($token in (Get-McpToken -Text $section.text)) {
            $tf[$token] = [int]$tf[$token] + 1
            $length++
        }
        if ($length -eq 0) { continue }
        foreach ($token in (Get-McpToken -Text $section.heading)) {
            $tf[$token] = [int]$tf[$token] + 2
            $length += 2
        }
        foreach ($token in $titleTokens) {
            $tf[$token] = [int]$tf[$token] + 1
            $length++
        }
        $chunks.Add([ordered]@{
                heading = $section.heading
                text    = $section.text
                len     = $length
                tf      = $tf
            })
    }
    , $chunks.ToArray()
}
