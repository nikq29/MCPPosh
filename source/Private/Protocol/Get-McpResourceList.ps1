function Get-McpResourceList {
    <#
    .SYNOPSIS
        Handles the MCP method resources/list.

    .DESCRIPTION
        Returns the documents of the knowledge base as MCP resources (URI mcpposh://<knowledge base>/documents/<id>, title, description, MIME type text/markdown and size), sorted by title and paged with a cursor of 500 entries.

    .PARAMETER Context
        The server context created by New-McpServerContext.

    .PARAMETER Params
        The params object of the request; an optional cursor selects the next page.

    .EXAMPLE
        Get-McpResourceList -Context $context -Params ([ordered]@{})

        Returns the first page of resources.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
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
