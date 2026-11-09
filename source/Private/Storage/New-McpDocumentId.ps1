function New-McpDocumentId {
    <#
    .SYNOPSIS
        Creates a readable, unique document id.

    .DESCRIPTION
        Creates a document id from the slug of the title and a random six-character suffix, for example installation-guide-3f9a1c, and makes sure it does not collide with existing ids.

    .PARAMETER Title
        Title of the document; its slug becomes the readable part of the id.

    .PARAMETER ExistingIds
        Ids already used in the knowledge base. A new suffix is generated on collision.

    .EXAMPLE
        New-McpDocumentId -Title 'Installation Guide' -ExistingIds @('faq-1a2b3c')

        Returns for example installation-guide-3f9a1c.
    #>
    [CmdletBinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Generates an identifier only; no system state is changed.')]
    [OutputType([string])]
    param(
        [AllowEmptyString()]
        [string] $Title,

        [string[]] $ExistingIds = @()
    )

    $slug = ConvertTo-McpSlug -Text $Title
    do {
        $id = '{0}-{1}' -f $slug, [guid]::NewGuid().ToString('N').Substring(0, 6)
    } while ($ExistingIds -contains $id)
    $id
}
