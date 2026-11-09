function Get-McpServerStateFile {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $KnowledgeBaseName,

        [Parameter(Mandatory)]
        [int] $Port
    )

    Join-Path -Path (Get-McpServerStateRoot) -ChildPath ('{0}-{1}.json' -f (ConvertTo-McpSlug -Text $KnowledgeBaseName), $Port)
}
