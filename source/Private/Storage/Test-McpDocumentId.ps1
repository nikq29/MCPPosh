function Test-McpDocumentId {
    <#
    .SYNOPSIS
        Tests whether a string is a valid document id.

    .DESCRIPTION
        Returns $true when the id starts with a letter or digit and only contains letters, digits, underscores and hyphens (at most 128 characters). Document ids are used as file names below documents/ and index/, so ids with dots, path separators, drive letters or UNC prefixes are rejected; a manifest from an untrusted archive or share can therefore never point outside the knowledge base folder.

    .PARAMETER Id
        The document id to validate, for example install-guide-1a2b3c.

    .EXAMPLE
        Test-McpDocumentId -Id 'install-guide-1a2b3c'

        Returns $true. Test-McpDocumentId -Id '../secret' returns $false.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [AllowNull()]
        [string] $Id
    )

    # \z instead of $: $ also matches before a trailing newline.
    [regex]::IsMatch([string]$Id, '\A[A-Za-z0-9][A-Za-z0-9_-]{0,127}\z')
}
