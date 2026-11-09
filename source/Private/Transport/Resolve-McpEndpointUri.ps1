function Resolve-McpEndpointUri {
    <#
    .SYNOPSIS
        Normalizes a server URL to its /mcp endpoint (accepts the base URL or the endpoint).

    .DESCRIPTION
        Normalizes a server URL to its MCP endpoint: a base URL such as https://docs.example.com gets /mcp appended, an URL that already ends with /mcp is returned unchanged. Relative URLs are rejected.

    .PARAMETER Uri
        Base URL or MCP endpoint URL of an MCPPosh HTTP server.

    .EXAMPLE
        Resolve-McpEndpointUri -Uri 'https://docs.example.com'

        Returns https://docs.example.com/mcp.
    #>
    [CmdletBinding()]
    [OutputType([uri])]
    param(
        [Parameter(Mandatory)]
        [uri] $Uri
    )

    if (-not $Uri.IsAbsoluteUri) {
        throw "'$Uri' is not an absolute URL."
    }
    $text = $Uri.AbsoluteUri.TrimEnd('/')
    if ($text -notmatch '/mcp$') { $text += '/mcp' }
    [uri]$text
}
