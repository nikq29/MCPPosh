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
