function Get-McpKnowledgeBaseRoot {
    <#
    .SYNOPSIS
        Returns the folder that contains the knowledge bases.

    .DESCRIPTION
        Returns the knowledgebases folder below the MCPPosh data directory (see Get-McpHomePath) and creates it when it does not exist yet.

    .EXAMPLE
        Get-McpKnowledgeBaseRoot

        Returns for example /home/user/.mcpposh/knowledgebases.
    #>
    [CmdletBinding()]
    param()

    $path = Join-Path -Path (Get-McpHomePath) -ChildPath 'knowledgebases'
    if (-not [System.IO.Directory]::Exists($path)) {
        $null = [System.IO.Directory]::CreateDirectory($path)
    }
    $path
}
