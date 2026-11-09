function Get-McpKnowledgeBaseArgumentCompletion {
    <#
    .SYNOPSIS
        Completes knowledge base names for tab completion.

    .DESCRIPTION
        Argument completer registered for the -KnowledgeBase and -Name parameters of the MCPPosh cmdlets. Returns completion results for all knowledge bases whose names start with the typed text.

    .PARAMETER commandName
        Name of the command whose parameter is completed. Provided by PowerShell and not used.

    .PARAMETER parameterName
        Name of the parameter that is completed. Provided by PowerShell and not used.

    .PARAMETER wordToComplete
        The text typed so far; knowledge base names starting with this text are returned.

    .PARAMETER commandAst
        Syntax tree of the command being completed. Provided by PowerShell and not used.

    .PARAMETER fakeBoundParameters
        Parameters that are already bound for the command. Provided by PowerShell and not used.

    .EXAMPLE
        Get-McpKnowledgeBaseArgumentCompletion -commandName 'Get-McpDocument' -parameterName 'KnowledgeBase' -wordToComplete 'Con'

        Returns a completion result for the knowledge base Contoso, if it exists.
    #>
    [CmdletBinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'PowerShell calls argument completers with this fixed parameter set.')]
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $root = Get-McpKnowledgeBaseRoot
    Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "$wordToComplete*" -and (Test-Path -LiteralPath (Join-Path $_.FullName 'knowledgebase.json')) } |
        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_.Name, $_.Name, 'ParameterValue', $_.Name) }
}
