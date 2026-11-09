function Get-McpKnowledgeBaseArgumentCompletion {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $root = Get-McpKnowledgeBaseRoot
    Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "$wordToComplete*" -and (Test-Path -LiteralPath (Join-Path $_.FullName 'knowledgebase.json')) } |
        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_.Name, $_.Name, 'ParameterValue', $_.Name) }
}
