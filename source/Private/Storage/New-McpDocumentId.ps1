function New-McpDocumentId {
    [CmdletBinding()]
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
