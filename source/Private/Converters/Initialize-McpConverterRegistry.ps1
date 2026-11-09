function Initialize-McpConverterRegistry {
    [CmdletBinding()]
    param()

    $script:McpConverters = [System.Collections.Generic.List[object]]::new()
    $builtins = @(
        @{ Name = 'Markdown'; Extensions = '.md', '.markdown', '.mdx', '.mkd'; ScriptBlock = { param($Path) ConvertFrom-McpMarkdownFile -Path $Path } }
        @{ Name = 'Text'; Extensions = '.txt', '.text', '.log', '.rst', '.adoc', '.asciidoc', '.org', '.textile'; ScriptBlock = { param($Path) ConvertFrom-McpTextFile -Path $Path } }
        @{ Name = 'Html'; Extensions = '.html', '.htm', '.xhtml'; ScriptBlock = { param($Path) ConvertFrom-McpHtmlFile -Path $Path } }
        @{ Name = 'Docx'; Extensions = , '.docx'; ScriptBlock = { param($Path) ConvertFrom-McpDocxFile -Path $Path } }
        @{ Name = 'Pdf'; Extensions = , '.pdf'; ScriptBlock = { param($Path) ConvertFrom-McpPdfFile -Path $Path } }
        @{ Name = 'Csv'; Extensions = '.csv', '.tsv'; ScriptBlock = { param($Path) ConvertFrom-McpCsvFile -Path $Path } }
        @{ Name = 'Json'; Extensions = '.json', '.jsonc', '.json5', '.jsonl'; ScriptBlock = { param($Path) ConvertFrom-McpCodeFile -Path $Path -Language 'json' -Format 'Json' } }
        @{ Name = 'Yaml'; Extensions = '.yaml', '.yml'; ScriptBlock = { param($Path) ConvertFrom-McpCodeFile -Path $Path -Language 'yaml' -Format 'Yaml' } }
        @{ Name = 'Xml'; Extensions = '.xml', '.xsd', '.xsl', '.xslt', '.config', '.csproj', '.props', '.targets', '.resx', '.svg'; ScriptBlock = { param($Path) ConvertFrom-McpCodeFile -Path $Path -Language 'xml' -Format 'Xml' } }
        @{ Name = 'Code'; Extensions = [string[]]$script:McpCodeLanguages.Keys; ScriptBlock = { param($Path) ConvertFrom-McpCodeFile -Path $Path } }
    )
    foreach ($builtin in $builtins) {
        $script:McpConverters.Add([pscustomobject]@{
                PSTypeName  = 'MCPPosh.Converter'
                Name        = $builtin.Name
                Extensions  = [string[]]@($builtin.Extensions | Sort-Object)
                ScriptBlock = $builtin.ScriptBlock
                Builtin     = $true
            })
    }
}
