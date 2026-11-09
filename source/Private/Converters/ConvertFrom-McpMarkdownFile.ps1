function ConvertFrom-McpMarkdownFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $text = Read-McpTextFile -Path $Path
    $frontMatter = Split-McpFrontMatter -Text $text
    $title = if ($frontMatter.Title) { $frontMatter.Title } else { Get-McpMarkdownTitle -Markdown $frontMatter.Body }
    @{
        Content = $frontMatter.Body
        Title   = $title
        Tags    = $frontMatter.Tags
    }
}
