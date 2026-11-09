function Remove-McpKnowledgeBase {
    <#
    .SYNOPSIS
        Deletes a knowledge base including all of its documents.
    .EXAMPLE
        Remove-McpKnowledgeBase -Name OldDocs
    .EXAMPLE
        Remove-McpKnowledgeBase -Name Test -Confirm:$false
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [string[]] $Name
    )

    process {
        foreach ($entry in $Name) {
            $kb = Resolve-McpKnowledgeBase -KnowledgeBase $entry
            $running = @(Get-McpServerState | Where-Object { $_.kbPath -eq $kb.Path -and $_.Status -eq 'Running' })
            if ($running.Count -gt 0) {
                Write-Error -Message "Knowledge base '$($kb.Name)' is served by a running MCP server. Stop it first: Stop-McpServer -KnowledgeBase '$($kb.Name)'" -Category ResourceBusy -TargetObject $entry
                continue
            }
            if ($PSCmdlet.ShouldProcess($kb.Path, "Delete knowledge base '$($kb.Name)' and all of its documents")) {
                Remove-Item -LiteralPath $kb.Path -Recurse -Force
                $script:McpIndexCache.Remove($kb.Path)
            }
        }
    }
}
