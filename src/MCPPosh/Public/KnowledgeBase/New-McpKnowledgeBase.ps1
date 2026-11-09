function New-McpKnowledgeBase {
    <#
    .SYNOPSIS
        Creates a new knowledge base for documentation that an MCP server can serve.
    .DESCRIPTION
        A knowledge base is a folder that holds normalized Markdown documents, a manifest and a
        search index. By default it is created below $env:MCPPOSH_HOME (or ~/.mcpposh). Use -Path
        to place it somewhere else, e.g. on a mounted Azure Files share.

        The description is sent to the AI agent as server instructions and in the tool
        descriptions, so describe what the documentation covers and when the agent should use it.
    .PARAMETER Name
        Name of the knowledge base (letters, digits, '.', '_' and '-').
    .PARAMETER Description
        What the documentation is about. Shown to the AI agent.
    .PARAMETER Path
        Optional directory for the knowledge base. Defaults to $env:MCPPOSH_HOME/knowledgebases/<Name>.
    .EXAMPLE
        New-McpKnowledgeBase -Name Contoso -Description 'Internal documentation for the Contoso platform: architecture, runbooks and coding guidelines.'
    .EXAMPLE
        New-McpKnowledgeBase -Name Shared -Path Z:\mcpposh\Shared
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('MCPPosh.KnowledgeBase')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')]
        [string] $Name,

        [Parameter(Position = 1)]
        [AllowEmptyString()]
        [string] $Description = '',

        [string] $Path
    )

    $target = if ($Path) {
        [System.IO.Path]::GetFullPath($Path, (Get-Location -PSProvider FileSystem).ProviderPath)
    }
    else {
        Join-Path -Path (Get-McpKnowledgeBaseRoot) -ChildPath $Name
    }

    if (Test-Path -LiteralPath (Join-Path -Path $target -ChildPath 'knowledgebase.json')) {
        throw "A knowledge base already exists at '$target'."
    }

    if ($PSCmdlet.ShouldProcess($target, "Create knowledge base '$Name'")) {
        Initialize-McpKnowledgeBaseFolder -Path $target -Name $Name -Description $Description
        $kb = Resolve-McpKnowledgeBase -KnowledgeBase $(if ($Path) { $target } else { $Name })
        ConvertTo-McpKnowledgeBaseObject -KnowledgeBase $kb
    }
}
