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

function Get-McpResourceTemplateList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Context
    )

    [ordered]@{
        resourceTemplates = @(
            [ordered]@{
                uriTemplate = 'mcpposh://{0}/documents/{{id}}' -f $Context.KnowledgeBase.Name
                name        = 'document'
                title       = "Document in '$($Context.KnowledgeBase.Name)'"
                description = 'A document of the knowledge base as Markdown, addressed by its id.'
                mimeType    = 'text/markdown'
            }
        )
    }
}

function Read-McpResource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Context,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Params
    )

    $uri = $Params['uri']
    if ($uri -isnot [string] -or -not $uri) {
        throw (New-McpRpcError -Code -32602 -Message 'Invalid params: uri is required')
    }

    $match = [regex]::Match($uri, '^mcpposh://(?<kb>[^/]+)/documents/(?<id>[^/?#]+)$')
    $index = Update-McpServerIndex -Context $Context
    if (-not $match.Success -or $match.Groups['kb'].Value -ne $Context.KnowledgeBase.Name) {
        throw (New-McpRpcError -Code -32002 -Message 'Resource not found' -Data ([ordered]@{ uri = $uri }))
    }
    $id = [System.Uri]::UnescapeDataString($match.Groups['id'].Value)
    $record = $index.Documents[$id]
    $content = if ($record) { Get-McpDocumentContent -KbPath $Context.KnowledgeBase.Path -Id $id } else { $null }
    if ($null -eq $content) {
        throw (New-McpRpcError -Code -32002 -Message 'Resource not found' -Data ([ordered]@{ uri = $uri }))
    }

    [ordered]@{
        contents = @(
            [ordered]@{
                uri      = $uri
                mimeType = 'text/markdown'
                text     = $content
            }
        )
    }
}
