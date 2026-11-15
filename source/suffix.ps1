# Module initialization. ModuleBuilder places this file at the end of the built PSMcpKnowledgeBase.psm1,
# after all functions are defined.

Initialize-McpConverterRegistry

$mcpTypeData = @{
    'PSMcpKnowledgeBase.KnowledgeBase' = 'Name', 'Description', 'Documents', 'Updated'
    'PSMcpKnowledgeBase.Document'      = 'Id', 'Title', 'Format', 'Tags', 'Updated'
    'PSMcpKnowledgeBase.SearchResult'  = 'Score', 'Title', 'Heading', 'DocumentId'
    'PSMcpKnowledgeBase.Converter'     = 'Name', 'Extensions', 'Builtin'
    'PSMcpKnowledgeBase.Server'        = 'KnowledgeBase', 'Transport', 'Status', 'Url', 'ProcessId'
    'PSMcpKnowledgeBase.ClientConfig'  = 'Client', 'Transport', 'ServerName', 'ConfigFile'
    'PSMcpKnowledgeBase.TestResult'    = 'Target', 'Success', 'ProtocolVersion', 'Tools', 'ElapsedMs'
}
foreach ($mcpEntry in $mcpTypeData.GetEnumerator()) {
    Update-TypeData -TypeName $mcpEntry.Key -DefaultDisplayPropertySet $mcpEntry.Value -Force
}

# Tab completion for knowledge base names.
$mcpKnowledgeBaseCommands = @(Get-Command -Name '*-Mcp*' -CommandType Function |
        Where-Object { $_.Parameters.ContainsKey('KnowledgeBase') } |
        ForEach-Object -MemberName Name)
if ($mcpKnowledgeBaseCommands.Count -gt 0) {
    Register-ArgumentCompleter -CommandName $mcpKnowledgeBaseCommands -ParameterName 'KnowledgeBase' -ScriptBlock ${function:Get-McpKnowledgeBaseArgumentCompletion}
}
Register-ArgumentCompleter -CommandName 'Get-McpKnowledgeBase', 'Set-McpKnowledgeBase', 'Remove-McpKnowledgeBase', 'Export-McpKnowledgeBase', 'Publish-McpKnowledgeBase' `
    -ParameterName 'Name' -ScriptBlock ${function:Get-McpKnowledgeBaseArgumentCompletion}

Remove-Variable -Name mcpTypeData, mcpEntry, mcpKnowledgeBaseCommands -ErrorAction SilentlyContinue
