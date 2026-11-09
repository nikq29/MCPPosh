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

    .EXAMPLE
        Get-McpDocument -Tag obsolete | Remove-McpDocument -Confirm:$false
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
