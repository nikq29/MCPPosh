function Add-McpDocument {
    <#
    .SYNOPSIS
        Adds knowledge to a knowledge base: files, folders, web pages or inline text.

    .DESCRIPTION
        Files are converted to Markdown when they are added. Supported out of the box:
        Markdown, text, HTML, Word (.docx), PDF (with PSWritePDF or pdftotext), CSV/TSV,
        JSON, YAML, XML and source code. Register additional formats with
        Register-McpDocumentConverter.

        Adding the same file or URL again updates the existing document instead of creating a
        duplicate. Inline content (-Content) is matched by its title. Running MCP servers pick up
        changes automatically.

    .PARAMETER Path
        Files or folders to import. Wildcards are supported, and Get-ChildItem output can be piped in.

    .PARAMETER Recurse
        Import folders recursively.

    .PARAMETER Include
        Only import files whose name matches one of these wildcard patterns (e.g. *.md, *.docx).

    .PARAMETER Exclude
        Skip files whose name matches one of these wildcard patterns.

    .PARAMETER Url
        Web pages or online documents (HTML, Markdown, PDF, Word, JSON ...) to import.

    .PARAMETER Content
        Text to store as a document, e.g. a note or a snippet. Requires -Title.

    .PARAMETER Title
        Document title. Defaults to the title found in the document (front matter, first heading,
        HTML <title>, Word title) or the file name.

    .PARAMETER Tags
        Tags for filtering, e.g. 'runbook', 'api'.

    .PARAMETER Format
        Force a converter (e.g. Markdown, Text, Html, Docx, Pdf, Csv, Json, Yaml, Xml, Code or a
        custom converter name) instead of detecting it from the file extension or content type.

    .PARAMETER KnowledgeBase
        Name or path of the knowledge base. 'Default' is created automatically.

    .EXAMPLE
        Add-McpDocument -Path .\docs -Recurse -Include *.md, *.docx -Tags handbook

        Imports all Markdown and Word files below .\docs into the knowledge base Default and tags them with handbook. Files that were imported before are updated instead of duplicated.

    .EXAMPLE
        Get-ChildItem C:\Wiki -Filter *.html -Recurse | Add-McpDocument -KnowledgeBase Contoso

        Pipes HTML files from Get-ChildItem into the knowledge base Contoso. Navigation, scripts and styles are removed; headings, lists, tables and code blocks are kept.

    .EXAMPLE
        Add-McpDocument -Url https://learn.microsoft.com/powershell/scripting/overview -Tags powershell

        Downloads a web page, converts it to Markdown and stores the URL as source, so Update-McpDocument can refresh it later.

    .EXAMPLE
        Add-McpDocument -Title 'VPN troubleshooting' -Content 'Restart the agent with: Restart-Service vpnagent' -Tags vpn, runbook

        Stores a short note as a document. Running the command again with the same title updates the note.

    .INPUTS
        System.String, System.IO.FileInfo. You can pipe paths or file objects from Get-ChildItem, and objects with a Url or Uri property.

    .OUTPUTS
        MCPPosh.Document: Id, Title, Format, Tags, SourceType (File, Url, Inline or Agent), Source, Summary, Chars, Added, Updated, KnowledgeBase, Uri and, with -IncludeContent, Content.

    .LINK
        https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Add-McpDocument.md

    .LINK
        Get-McpDocument

    .LINK
        Update-McpDocument

    .LINK
        Register-McpDocumentConverter

    .LINK
        Search-McpDocument
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path', SupportsShouldProcess)]
    [OutputType('MCPPosh.Document')]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Path', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName', 'PSPath', 'LiteralPath')]
        [SupportsWildcards()]
        [string[]] $Path,

        [Parameter(ParameterSetName = 'Path')]
        [switch] $Recurse,

        [Parameter(ParameterSetName = 'Path')]
        [string[]] $Include,

        [Parameter(ParameterSetName = 'Path')]
        [string[]] $Exclude,

        [Parameter(Mandatory, ParameterSetName = 'Url', ValueFromPipelineByPropertyName)]
        [Alias('Uri')]
        [uri[]] $Url,

        [Parameter(Mandatory, ParameterSetName = 'Content')]
        [AllowEmptyString()]
        [string] $Content,

        [Parameter(ParameterSetName = 'Path')]
        [Parameter(ParameterSetName = 'Url')]
        [Parameter(Mandatory, ParameterSetName = 'Content')]
        [string] $Title,

        [string[]] $Tags = @(),

        [ArgumentCompletions('Markdown', 'Text', 'Html', 'Docx', 'Pdf', 'Csv', 'Json', 'Yaml', 'Xml', 'Code')]
        [string] $Format,

        [string] $KnowledgeBase = 'Default'
    )

    begin {
        $mergeTags = -not $PSBoundParameters.ContainsKey('Tags')
        $kb = Resolve-McpKnowledgeBase -KnowledgeBase $KnowledgeBase -CreateIfMissing:($KnowledgeBase -eq 'Default')

        $writeResult = {
            param($Saved)
            $state = if ($Saved.Created) { 'added' } elseif ($Saved.Changed) { 'updated' } else { 'unchanged' }
            Write-Verbose ("{0}: {1} ({2})" -f $state, $Saved.Record.title, $Saved.Record.id)
            ConvertTo-McpDocumentObject -Record $Saved.Record -KnowledgeBase $kb
        }

        $includePatterns = @($Include | Where-Object { $_ })
        $excludePatterns = @($Exclude | Where-Object { $_ })
    }

    process {
        switch ($PSCmdlet.ParameterSetName) {
            'Content' {
                if (-not $PSCmdlet.ShouldProcess($Title, "Add inline document to knowledge base '$($kb.Name)'")) { return }
                $markdown = $Content
                $documentFormat = if ($Format) { $Format } else { 'Markdown' }
                if ($Format -eq 'Html') {
                    $markdown = (ConvertFrom-McpHtml -Html $Content).Content
                }
                $saved = Save-McpDocument -KnowledgeBase $kb -Content $markdown -Title $Title -Format $documentFormat -SourceType Inline -Tags $Tags -MergeExistingTags:$mergeTags
                & $writeResult $saved
            }

            'Url' {
                foreach ($address in $Url) {
                    if (-not $address.IsAbsoluteUri -or $address.Scheme -notin 'http', 'https') {
                        Write-Error -Message "Only absolute http(s) URLs are supported: '$address'." -Category InvalidArgument -TargetObject $address
                        continue
                    }
                    if (-not $PSCmdlet.ShouldProcess($address.AbsoluteUri, "Import into knowledge base '$($kb.Name)'")) { continue }
                    try {
                        $converted = Get-McpWebDocument -Url $address -Format $Format
                        $documentTitle = if ($Title) { $Title } else { $converted['Title'] }
                        $allTags = @($Tags) + @($converted['Tags'])
                        $saved = Save-McpDocument -KnowledgeBase $kb -Content $converted['Content'] -Title $documentTitle -Format $converted['Format'] -SourceType Url -Source $address.AbsoluteUri -Tags $allTags -MergeExistingTags:$mergeTags
                        & $writeResult $saved
                    }
                    catch {
                        Write-Error -Message "Failed to import '$address': $($_.Exception.Message)" -Category InvalidData -TargetObject $address
                    }
                }
            }

            'Path' {
                $files = [System.Collections.Generic.List[string]]::new()
                foreach ($entry in $Path) {
                    $items = if (Test-Path -LiteralPath $entry) {
                        Get-Item -LiteralPath $entry -Force
                    }
                    else {
                        Get-Item -Path $entry -Force -ErrorAction SilentlyContinue
                    }
                    if (-not $items) {
                        Write-Error -Message "Path not found: '$entry'." -Category ObjectNotFound -TargetObject $entry
                        continue
                    }
                    foreach ($item in @($items)) {
                        if ($item.PSIsContainer) {
                            $children = Get-ChildItem -LiteralPath $item.FullName -File -Recurse:$Recurse -ErrorAction SilentlyContinue |
                                Where-Object { $_.FullName -notmatch '[\\/](\.git|\.svn|\.hg|node_modules|\.mcpposh)[\\/]' }
                            $candidates = @($children)
                        }
                        else {
                            $candidates = @($item)
                        }
                        foreach ($candidate in $candidates) {
                            $included = $includePatterns.Count -eq 0 -or @($includePatterns | Where-Object { $candidate.Name -like $_ }).Count -gt 0
                            $excluded = $excludePatterns.Count -gt 0 -and @($excludePatterns | Where-Object { $candidate.Name -like $_ }).Count -gt 0
                            if ($included -and -not $excluded) { $files.Add($candidate.FullName) }
                        }
                    }
                }

                foreach ($file in $files) {
                    if (-not $PSCmdlet.ShouldProcess($file, "Import into knowledge base '$($kb.Name)'")) { continue }
                    try {
                        $converted = ConvertTo-McpMarkdown -Path $file -Format $Format
                        $documentTitle = if ($Title) { $Title } else { $converted['Title'] }
                        $allTags = @($Tags) + @($converted['Tags'])
                        $sourceHash = Get-McpSha256 -Path $file
                        $saved = Save-McpDocument -KnowledgeBase $kb -Content $converted['Content'] -Title $documentTitle -Format $converted['Format'] -SourceType File -Source $file -SourceHash $sourceHash -Tags $allTags -MergeExistingTags:$mergeTags
                        & $writeResult $saved
                    }
                    catch {
                        Write-Error -Message "Failed to import '$file': $($_.Exception.Message)" -Category InvalidData -TargetObject $file
                    }
                }
            }
        }
    }
}
