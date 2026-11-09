function Read-McpResource {
    <#
    .SYNOPSIS
        Handles the MCP method resources/read.

    .DESCRIPTION
        Returns the Markdown content of the document addressed by a mcpposh://<knowledge base>/documents/<id> URI. Unknown URIs or documents result in the resource-not-found error -32002.

    .PARAMETER Context
        The server context created by New-McpServerContext.

    .PARAMETER Params
        The params object of the request with the uri of the resource to read.

    .EXAMPLE
        Read-McpResource -Context $context -Params ([ordered]@{ uri = 'mcpposh://Contoso/documents/install-1a2b3c' })

        Returns the contents result with the Markdown text.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
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
