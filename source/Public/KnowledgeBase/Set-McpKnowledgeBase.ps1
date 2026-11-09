function Set-McpKnowledgeBase {
    <#
    .SYNOPSIS
        Changes the description of a knowledge base.

    .DESCRIPTION
        The description is sent to the AI agent as MCP server instructions. Running servers pick
        up the change automatically.

    .PARAMETER Name
        Name or directory path of the knowledge base to change. Accepts the Name property through the pipeline.

    .PARAMETER Description
        New description of the knowledge base. It is sent to AI agents as MCP server instructions.

    .PARAMETER PassThru
        Returns the updated knowledge base object. By default the cmdlet does not produce output.

    .EXAMPLE
        Set-McpKnowledgeBase -Name Contoso -Description 'Runbooks and architecture of the Contoso platform. Use it for any question about Contoso.'

        Changes the description that AI agents receive as server instructions. Running servers pick up the change automatically.

    .INPUTS
        System.String. You can pipe objects with a Name property, for example from Get-McpKnowledgeBase.

    .OUTPUTS
        None by default. With -PassThru: MCPPosh.KnowledgeBase: Name, Description, Documents, Characters, Tags, Revision, Created, Updated and Path.

    .LINK
        https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Set-McpKnowledgeBase.md

    .LINK
        Get-McpKnowledgeBase

    .LINK
        New-McpKnowledgeBase
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('MCPPosh.KnowledgeBase')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [string] $Name,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Description,

        [switch] $PassThru
    )

    process {
        $kb = Resolve-McpKnowledgeBase -KnowledgeBase $Name
        if (-not $PSCmdlet.ShouldProcess($kb.Name, 'Update knowledge base description')) { return }

        $kbLock = Lock-McpKnowledgeBase -KbPath $kb.Path
        try {
            $metaPath = Join-Path -Path $kb.Path -ChildPath 'knowledgebase.json'
            $meta = Read-McpJsonFile -Path $metaPath
            $meta['description'] = $Description
            Write-McpJsonFile -Path $metaPath -InputObject $meta
            # Touch the manifest so running servers reload (they watch manifest.json).
            Save-McpManifest -KbPath $kb.Path -Manifest (Read-McpManifest -KbPath $kb.Path)
        }
        finally {
            $kbLock.Dispose()
        }
        if ($PassThru) {
            ConvertTo-McpKnowledgeBaseObject -KnowledgeBase (Resolve-McpKnowledgeBase -KnowledgeBase $Name)
        }
    }
}
