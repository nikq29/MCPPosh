function Set-McpKnowledgeBase {
    <#
    .SYNOPSIS
        Changes the description of a knowledge base.
    .DESCRIPTION
        The description is sent to the AI agent as MCP server instructions. Running servers pick
        up the change automatically.
    .EXAMPLE
        Set-McpKnowledgeBase -Name Contoso -Description 'Runbooks and architecture of the Contoso platform. Use it for any question about Contoso.'
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

        Invoke-McpKnowledgeBaseLock -KbPath $kb.Path -ScriptBlock {
            $metaPath = Join-Path -Path $kb.Path -ChildPath 'knowledgebase.json'
            $meta = Read-McpJsonFile -Path $metaPath
            $meta['description'] = $Description
            Write-McpJsonFile -Path $metaPath -InputObject $meta
            # Touch the manifest so running servers reload (they watch manifest.json).
            Save-McpManifest -KbPath $kb.Path -Manifest (Read-McpManifest -KbPath $kb.Path)
        }
        if ($PassThru) {
            ConvertTo-McpKnowledgeBaseObject -KnowledgeBase (Resolve-McpKnowledgeBase -KnowledgeBase $Name)
        }
    }
}
