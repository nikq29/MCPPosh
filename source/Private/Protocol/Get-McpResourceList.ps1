function Get-McpResourceList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Context,

        [System.Collections.IDictionary] $Params
    )

    $pageSize = 500
    $offset = 0
    if ($Params -and $Params['cursor']) {
        if (-not [int]::TryParse([string]$Params['cursor'], [ref] $offset) -or $offset -lt 0) {
            throw (New-McpRpcError -Code -32602 -Message 'Invalid params: invalid cursor')
        }
    }

    $index = Update-McpServerIndex -Context $Context
    $kbName = $Context.KnowledgeBase.Name
    $documents = @($index.Documents.Values | Sort-Object -Property { $_.title })
    $page = @($documents | Select-Object -Skip $offset -First $pageSize)
    $resources = foreach ($doc in $page) {
        $resource = [ordered]@{
            uri      = 'mcpposh://{0}/documents/{1}' -f $kbName, $doc.id
            name     = [string]$doc.id
            title    = [string]$doc.title
            mimeType = 'text/markdown'
        }
        if ($doc.summary) { $resource['description'] = [string]$doc.summary }
        if ($doc.chars) { $resource['size'] = [long]$doc.chars }
        $resource
    }

    $result = [ordered]@{ resources = @($resources) }
    if ($offset + $page.Count -lt $documents.Count) {
        $result['nextCursor'] = [string]($offset + $page.Count)
    }
    $result
}
