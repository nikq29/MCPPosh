function Set-McpDocument {
    <#
    .SYNOPSIS
        Changes the title, tags or content of a document.
    .PARAMETER Id
        Id of the document.
    .PARAMETER Title
        New title.
    .PARAMETER Tags
        Replaces all tags.
    .PARAMETER AddTags
        Tags to add.
    .PARAMETER RemoveTags
        Tags to remove.
    .PARAMETER Content
        Replaces the Markdown content. Note that Update-McpDocument re-imports file and URL
        documents from their source and would overwrite manual content changes.
    .EXAMPLE
        Set-McpDocument -Id vpn-troubleshooting-1a2b3c -AddTags network
    .EXAMPLE
        Get-McpDocument -Tag draft | Set-McpDocument -RemoveTags draft -AddTags reviewed
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
            $updated = Set-McpDocumentMetadata @metadata
        }

        if ($PassThru) {
            ConvertTo-McpDocumentObject -Record $updated -KnowledgeBase $kb
        }
    }
}
