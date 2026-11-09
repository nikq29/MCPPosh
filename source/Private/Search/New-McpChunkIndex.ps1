function New-McpChunkIndex {
    <#
    .SYNOPSIS
        Chunks a document and pre-computes the term frequencies used by the BM25 search.
    #>
    [CmdletBinding()]
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
