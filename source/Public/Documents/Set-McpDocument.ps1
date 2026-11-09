function Set-McpDocument {
    <#
    .SYNOPSIS
        Changes the title, tags or content of a document.

    .DESCRIPTION
        Changes the title, the tags or the Markdown content of an existing document and refreshes its search index. Use -AddTags and -RemoveTags to edit tags incrementally.

    .PARAMETER Id
        Id of the document to change. Accepts the Id property of objects from Get-McpDocument through the pipeline.

    .PARAMETER Title
        New title of the document. The title is also indexed for the search.

    .PARAMETER Tags
        Replaces all tags of the document with these tags. Pass an empty array to remove all tags.

    .PARAMETER AddTags
        Tags to add to the existing tags of the document.

    .PARAMETER RemoveTags
        Tags to remove from the existing tags of the document.

    .PARAMETER Content
        Replaces the Markdown content. Note that Update-McpDocument re-imports file and URL
        documents from their source and would overwrite manual content changes.

    .PARAMETER KnowledgeBase
        Name or directory path of the knowledge base that contains the document. Defaults to Default.

    .PARAMETER PassThru
        Returns the updated document object. By default the cmdlet does not produce output.

    .EXAMPLE
        Set-McpDocument -Id vpn-troubleshooting-1a2b3c -AddTags network

        Adds the tag network to a document of the knowledge base Default.

    .EXAMPLE
        Get-McpDocument -Tag draft | Set-McpDocument -RemoveTags draft -AddTags reviewed

        Replaces the tag draft with reviewed on all draft documents.

    .EXAMPLE
        Set-McpDocument -Id vpn-troubleshooting-1a2b3c -Title 'VPN: troubleshooting guide' -PassThru

        Renames a document and returns the updated document.

    .INPUTS
        MCPPosh.Document. You can pipe documents from Get-McpDocument; Id and KnowledgeBase bind by property name.

    .OUTPUTS
        None by default. With -PassThru: MCPPosh.Document: Id, Title, Format, Tags, SourceType (File, Url, Inline or Agent), Source, Summary, Chars, Added, Updated, KnowledgeBase, Uri and, with -IncludeContent, Content.

    .LINK
        https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Set-McpDocument.md

    .LINK
        Get-McpDocument

    .LINK
        Update-McpDocument
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('MCPPosh.Document')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [string] $Id,

        [string] $Title,

        [AllowEmptyCollection()]
        [string[]] $Tags,

        [string[]] $AddTags,

        [string[]] $RemoveTags,

        [AllowEmptyString()]
        [string] $Content,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $KnowledgeBase = 'Default',

        [switch] $PassThru
    )

    process {
        $kb = Resolve-McpKnowledgeBase -KnowledgeBase $KnowledgeBase
        $record = Find-McpDocumentRecord -Documents @((Read-McpManifest -KbPath $kb.Path)['documents']) -Id $Id
        if (-not $record) {
            Write-Error -Message "Document '$Id' was not found in knowledge base '$($kb.Name)'." -Category ObjectNotFound -TargetObject $Id
            return
        }
        if (-not $PSCmdlet.ShouldProcess("$($record.title) ($Id)", 'Update document')) { return }

        $newTags = @($record.tags)
        $tagsChanged = $false
        if ($PSBoundParameters.ContainsKey('Tags')) { $newTags = @($Tags); $tagsChanged = $true }
        if ($AddTags) { $newTags = @($newTags) + @($AddTags); $tagsChanged = $true }
        if ($RemoveTags) { $newTags = @($newTags | Where-Object { $RemoveTags -notcontains $_ }); $tagsChanged = $true }

        if ($PSBoundParameters.ContainsKey('Content')) {
            $saved = Save-McpDocument -KnowledgeBase $kb -Id $Id -Content $Content `
                -Title $(if ($Title) { $Title } else { [string]$record.title }) `
                -Format ([string]$record.format) -SourceType ([string]$record.sourceType) -Source ([string]$record.source) `
                -SourceHash ([string]$record.sourceHash) -Tags $newTags
            $updated = $saved.Record
        }
        else {
            $metadata = @{ KnowledgeBase = $kb; Id = $Id }
            if ($Title) { $metadata['Title'] = $Title }
            if ($tagsChanged) { $metadata['Tags'] = [string[]]@($newTags) }
            $updated = Set-McpDocumentProperty @metadata
        }

        if ($PassThru) {
            ConvertTo-McpDocumentObject -Record $updated -KnowledgeBase $kb
        }
    }
}
