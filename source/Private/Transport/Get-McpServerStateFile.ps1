function Get-McpServerStateFile {
    <#
    .SYNOPSIS
        Returns the path of the state file of a local HTTP server.

    .DESCRIPTION
        Returns the path of the JSON state file for the HTTP server of a knowledge base on a port: servers/<knowledge base slug>-<port>.json in the MCPPosh data directory.

    .PARAMETER KnowledgeBaseName
        Name of the knowledge base the server provides.

    .PARAMETER Port
        TCP port the server listens on.

    .EXAMPLE
        Get-McpServerStateFile -KnowledgeBaseName Contoso -Port 5050

        Returns for example ~/.mcpposh/servers/contoso-5050.json.
    #>
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
