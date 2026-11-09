function Find-McpDocumentRecord {
    <#
    .SYNOPSIS
        Finds an existing document record in the manifest.

    .DESCRIPTION
        Finds a document record by id, by source (file and URL documents) or by title (inline documents and agent notes). Add-McpDocument uses it to update existing documents instead of creating duplicates.

    .PARAMETER Documents
        The document records of the manifest to search, as an array of ordered dictionaries.

    .PARAMETER Id
        Id of the document to find. When it is set, the other criteria are ignored.

    .PARAMETER SourceType
        Source type of the document: File, Url, Inline or Agent. Determines whether Source or Title is compared.

    .PARAMETER Source
        Full path or URL of the source, compared for documents of type File and Url.

    .PARAMETER Title
        Title of the document, compared for documents of type Inline and Agent.

    .EXAMPLE
        Find-McpDocumentRecord -Documents @($manifest.documents) -SourceType File -Source '/docs/install.md'

        Returns the record that was imported from /docs/install.md, or $null.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Documents,

        [string] $Id,

        [string] $SourceType,

        [string] $Source,

        [string] $Title
    )

    foreach ($doc in $Documents) {
        if ($Id) {
            if ($doc.id -eq $Id) { return $doc }
            continue
        }
        if ($SourceType -in 'File', 'Url' -and $Source) {
            if ($doc.sourceType -eq $SourceType -and $doc.source -eq $Source) { return $doc }
            continue
        }
        if ($SourceType -in 'Inline', 'Agent' -and $Title) {
            if ($doc.sourceType -eq $SourceType -and $doc.title -eq $Title) { return $doc }
        }
    }
    $null
}
