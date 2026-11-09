function Get-McpKnowledgeBaseRoot {
    [CmdletBinding()]
    param()

    $path = Join-Path -Path (Get-McpHomePath) -ChildPath 'knowledgebases'
    if (-not [System.IO.Directory]::Exists($path)) {
        $null = [System.IO.Directory]::CreateDirectory($path)
    }
    $path
}
