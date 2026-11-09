function Resolve-McpEndpointUri {
    <#
    .SYNOPSIS
        Normalizes a server URL to its /mcp endpoint (accepts the base URL or the endpoint).
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
