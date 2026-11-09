#Requires -Version 7.2

$script:ModuleRoot = $PSScriptRoot
$script:ModuleManifestPath = Join-Path -Path $PSScriptRoot -ChildPath 'MCPPosh.psd1'
$script:ModuleVersion = [string](Import-PowerShellDataFile -Path $script:ModuleManifestPath).ModuleVersion

foreach ($folder in 'Private', 'Public') {
    $folderPath = Join-Path -Path $PSScriptRoot -ChildPath $folder
    if (Test-Path -LiteralPath $folderPath) {
        foreach ($file in (Get-ChildItem -LiteralPath $folderPath -Filter '*.ps1' -Recurse -File | Sort-Object -Property FullName)) {
            . $file.FullName
        }
    }
}

Initialize-McpConverterRegistry

$typeData = @{
    'MCPPosh.KnowledgeBase' = 'Name', 'Description', 'Documents', 'Updated'
    'MCPPosh.Document'      = 'Id', 'Title', 'Format', 'Tags', 'Updated'
    'MCPPosh.SearchResult'  = 'Score', 'Title', 'Heading', 'DocumentId'
    'MCPPosh.Converter'     = 'Name', 'Extensions', 'Builtin'
    'MCPPosh.Server'        = 'KnowledgeBase', 'Transport', 'Status', 'Url', 'ProcessId'
    'MCPPosh.ClientConfig'  = 'Client', 'Transport', 'ServerName', 'ConfigFile'
    'MCPPosh.TestResult'    = 'Target', 'Success', 'ProtocolVersion', 'Tools', 'ElapsedMs'
}
foreach ($entry in $typeData.GetEnumerator()) {
    Update-TypeData -TypeName $entry.Key -DefaultDisplayPropertySet $entry.Value -Force
}

$publicFunctions = Get-ChildItem -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath 'Public') -Filter '*.ps1' -Recurse -File |
    ForEach-Object -MemberName BaseName

# Tab completion for knowledge base names.
$knowledgeBaseCommands = foreach ($functionName in $publicFunctions) {
    $command = Get-Command -Name $functionName -CommandType Function
    if ($command.Parameters.ContainsKey('KnowledgeBase')) { $functionName }
}
if ($knowledgeBaseCommands) {
    Register-ArgumentCompleter -CommandName $knowledgeBaseCommands -ParameterName 'KnowledgeBase' -ScriptBlock ${function:Get-McpKnowledgeBaseArgumentCompletion}
}
Register-ArgumentCompleter -CommandName 'Get-McpKnowledgeBase', 'Set-McpKnowledgeBase', 'Remove-McpKnowledgeBase', 'Export-McpKnowledgeBase', 'Publish-McpKnowledgeBase' `
    -ParameterName 'Name' -ScriptBlock ${function:Get-McpKnowledgeBaseArgumentCompletion}

Export-ModuleMember -Function $publicFunctions
