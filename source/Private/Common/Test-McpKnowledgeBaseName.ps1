function Test-McpKnowledgeBaseName {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Name
    )

    $Name -match '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$'
}
