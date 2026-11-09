function Update-McpDocument {
    <#
    .SYNOPSIS
        Re-imports file and URL documents from their original source when the source changed.

    .DESCRIPTION
        For file documents the source file hash is compared; URL documents are downloaded again.
        Inline documents and agent notes have no source and are skipped. Use -Force to re-import
        even unchanged sources (e.g. after installing PDF support or registering a converter).

    .PARAMETER Id
        Documents to update. Use -All to update every document.

    .PARAMETER All
        Updates every document of the knowledge base instead of the documents named with -Id.

    .PARAMETER Force
        Re-imports documents even when the source has not changed, for example after installing PDF support.

    .PARAMETER RemoveMissing
        Remove file documents whose source file no longer exists.

    .PARAMETER KnowledgeBase
        Name or directory path of the knowledge base that contains the documents. Defaults to Default.

    .EXAMPLE
        Update-McpDocument -All -KnowledgeBase Contoso

        Re-imports every file and URL document of the knowledge base Contoso whose source changed.

    .EXAMPLE
        Get-McpDocument -SourceType Url | Update-McpDocument -Force

        Downloads and converts all web documents of the knowledge base Default again, even if they did not change.

    .EXAMPLE
        Update-McpDocument -All -RemoveMissing

        Updates all documents and removes documents whose source file no longer exists.

    .INPUTS
        MCPPosh.Document. You can pipe documents from Get-McpDocument; Id and KnowledgeBase bind by property name.

    .OUTPUTS
        MCPPosh.Document: Id, Title, Format, Tags, SourceType (File, Url, Inline or Agent), Source, Summary, Chars, Added, Updated, KnowledgeBase, Uri and, with -IncludeContent, Content. Only documents that were re-imported are returned.

    .LINK
        https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Update-McpDocument.md

    .LINK
        Add-McpDocument

    .LINK
        Get-McpDocument
    #>
    [CmdletBinding(DefaultParameterSetName = 'Id', SupportsShouldProcess)]
    [OutputType('MCPPosh.Document')]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Id', ValueFromPipelineByPropertyName)]
        [string[]] $Id,

        [Parameter(Mandatory, ParameterSetName = 'All')]
        [switch] $All,

        [switch] $Force,

        [switch] $RemoveMissing,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $KnowledgeBase = 'Default'
    )

    process {
        $kb = Resolve-McpKnowledgeBase -KnowledgeBase $KnowledgeBase
        $documents = @((Read-McpManifest -KbPath $kb.Path)['documents'])
        $targets = if ($All) { $documents } else { @($documents | Where-Object { $Id -contains $_.id }) }
        if (-not $All) {
            foreach ($missing in @($Id | Where-Object { $documents.id -notcontains $_ })) {
                Write-Error -Message "Document '$missing' was not found in knowledge base '$($kb.Name)'." -Category ObjectNotFound -TargetObject $missing
            }
        }

        foreach ($record in $targets) {
            $label = "$($record.title) ($($record.id))"
            switch ($record.sourceType) {
                'File' {
                    $source = [string]$record.source
                    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
                        if ($RemoveMissing) {
                            if ($PSCmdlet.ShouldProcess($label, 'Remove document (source file is missing)')) {
                                Remove-McpDocumentRecord -KnowledgeBase $kb -Id $record.id
                            }
                        }
                        else {
                            Write-Warning "Source file of '$label' was not found: $source"
                        }
                        continue
                    }
                    $sourceHash = Get-McpSha256 -Path $source
                    if (-not $Force -and $sourceHash -eq $record.sourceHash) {
                        Write-Verbose "unchanged: $label"
                        continue
                    }
                    if (-not $PSCmdlet.ShouldProcess($label, "Re-import from $source")) { continue }
                    try {
                        $converted = ConvertTo-McpMarkdown -Path $source -Format ([string]$record.format)
                        $saved = Save-McpDocument -KnowledgeBase $kb -Id $record.id -Content $converted['Content'] -Title ([string]$record.title) `
                            -Format $converted['Format'] -SourceType File -Source $source -SourceHash $sourceHash -Tags @($record.tags)
                        if ($saved.Changed) { ConvertTo-McpDocumentObject -Record $saved.Record -KnowledgeBase $kb }
                    }
                    catch {
                        Write-Error -Message "Failed to update '$label': $($_.Exception.Message)" -Category InvalidData -TargetObject $record.id
                    }
                }
                'Url' {
                    if (-not $PSCmdlet.ShouldProcess($label, "Re-import from $($record.source)")) { continue }
                    try {
                        $converted = Get-McpWebDocument -Url ([uri][string]$record.source)
                        $saved = Save-McpDocument -KnowledgeBase $kb -Id $record.id -Content $converted['Content'] -Title ([string]$record.title) `
                            -Format $converted['Format'] -SourceType Url -Source ([string]$record.source) -Tags @($record.tags)
                        if ($saved.Changed) { ConvertTo-McpDocumentObject -Record $saved.Record -KnowledgeBase $kb }
                        else { Write-Verbose "unchanged: $label" }
                    }
                    catch {
                        Write-Error -Message "Failed to update '$label': $($_.Exception.Message)" -Category ConnectionError -TargetObject $record.id
                    }
                }
                default {
                    Write-Verbose "skipped (no source): $label"
                }
            }
        }
    }
}
