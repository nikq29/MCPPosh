function Test-McpKnowledgeBaseName {
    <#
    .SYNOPSIS
        Tests whether a string is a valid knowledge base name.

    .DESCRIPTION
        Returns $true when the name starts with a letter or digit and only contains letters, digits, dots, underscores and hyphens (at most 64 characters), so it can be used as a folder name on all platforms.

    .PARAMETER Name
        The knowledge base name to validate, for example Contoso or team-docs.

    .EXAMPLE
        Test-McpKnowledgeBaseName -Name 'team-docs'

        Returns $true.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Name
    )

    $Name -match '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$'
}
