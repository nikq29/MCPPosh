function Remove-McpDocument {
    <#
    .SYNOPSIS
        Removes documents from a knowledge base.
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
