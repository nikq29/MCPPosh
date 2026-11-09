function ConvertTo-McpKnowledgeBaseObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $KnowledgeBase
    )

    $manifest = Read-McpManifest -KbPath $KnowledgeBase.Path
    $documents = @($manifest['documents'])
    [pscustomobject]@{
        PSTypeName  = 'MCPPosh.KnowledgeBase'
        Name        = $KnowledgeBase.Name
        Description = $KnowledgeBase.Description
        Documents   = $documents.Count
        Characters  = [long](($documents | ForEach-Object { [long]$_.chars } | Measure-Object -Sum).Sum)
        Tags        = [string[]]@($documents | ForEach-Object { $_.tags } | Where-Object { $_ } | Sort-Object -Unique)
        Revision    = [long]$manifest['revision']
        Created     = ConvertTo-McpDateTime -Value $KnowledgeBase.Created
        Updated     = ConvertTo-McpDateTime -Value $manifest['updated']
        Path        = $KnowledgeBase.Path
    }
}

function Get-McpKnowledgeBaseArgumentCompletion {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $root = Get-McpKnowledgeBaseRoot
    Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "$wordToComplete*" -and (Test-Path -LiteralPath (Join-Path $_.FullName 'knowledgebase.json')) } |
        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_.Name, $_.Name, 'ParameterValue', $_.Name) }
}
