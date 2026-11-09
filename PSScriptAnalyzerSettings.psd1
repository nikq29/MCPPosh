@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        # Private helpers named New-/Set-/Remove-/Start-* operate on in-memory state or are
        # wrapped by public cmdlets that implement ShouldProcess.
        'PSUseShouldProcessForStateChangingFunctions'
        # Helper names such as Get-McpDocumentPaths / Get-McpKnowledgeBaseFiles return collections.
        'PSUseSingularNouns'
        # Write-Host is used intentionally in the container entry point and deploy script.
        'PSAvoidUsingWriteHost'
        # Argument completers must accept the full parameter set even if unused.
        'PSReviewUnusedParameter'
    )
}
