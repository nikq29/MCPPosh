function Remove-McpDocument {
    <#
    .SYNOPSIS
        Removes documents from a knowledge base.

    .DESCRIPTION
        Removes documents from a knowledge base, including their Markdown content and search index. Running MCP servers stop returning the documents automatically.

    .PARAMETER Id
        Ids of the documents to remove. Accepts the Id property of objects from Get-McpDocument through the pipeline.

    .PARAMETER KnowledgeBase
        Name or directory path of the knowledge base that contains the documents. Defaults to Default.

    .EXAMPLE
        Remove-McpDocument -Id old-runbook-1a2b3c

        Removes one document from the knowledge base Default after confirmation.

    .EXAMPLE
        Get-McpDocument -Tag obsolete | Remove-McpDocument -Confirm:$false

        Removes all documents with the tag obsolete without asking for confirmation.

    .INPUTS
        MCPPosh.Document. You can pipe documents from Get-McpDocument; Id and KnowledgeBase bind by property name.

    .OUTPUTS
        None.

    .LINK
        https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Remove-McpDocument.md

    .LINK
        Get-McpDocument

    .LINK
        Add-McpDocument
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [string[]] $Id,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $KnowledgeBase = 'Default'
    )

    process {
        $kb = Resolve-McpKnowledgeBase -KnowledgeBase $KnowledgeBase
        foreach ($documentId in $Id) {
            if (-not $PSCmdlet.ShouldProcess($documentId, "Remove document from knowledge base '$($kb.Name)'")) { continue }
            try {
                Remove-McpDocumentRecord -KnowledgeBase $kb -Id $documentId
            }
            catch {
                Write-Error -Message $_.Exception.Message -Category ObjectNotFound -TargetObject $documentId
            }
        }
    }
}
