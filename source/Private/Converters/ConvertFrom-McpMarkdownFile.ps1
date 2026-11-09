function ConvertFrom-McpMarkdownFile {
    <#
    .SYNOPSIS
        Reads a Markdown file including its front matter.

    .DESCRIPTION
        Reads a Markdown file, removes YAML front matter and takes the title and tags from it. Without a front matter title the first level-one heading is used.

    .PARAMETER Path
        Path of the Markdown file to read (.md, .markdown or .mdx).

    .EXAMPLE
        ConvertFrom-McpMarkdownFile -Path ./docs/install.md

        Returns a hashtable with Content, Title and Tags.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
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
