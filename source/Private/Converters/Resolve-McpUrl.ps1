function Resolve-McpUrl {
    <#
    .SYNOPSIS
        Resolves a link against a base URL.

    .DESCRIPTION
        Turns a relative link into an absolute URL using the base URL of the page it was found on. Returns the link unchanged when no base URL is given or it cannot be resolved.

    .PARAMETER Href
        The link target from the HTML, absolute or relative.

    .PARAMETER BaseUrl
        Absolute URL of the page that contains the link.

    .EXAMPLE
        Resolve-McpUrl -Href 'details.html' -BaseUrl 'https://docs.example.com/vpn/index.html'

        Returns https://docs.example.com/vpn/details.html.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string] $Href,

        [string] $BaseUrl
    )

    if (-not $BaseUrl) { return $Href }
    try {
        $base = [uri]::new($BaseUrl)
        return [uri]::new($base, $Href).AbsoluteUri
    }
    catch {
        return $Href
    }
}
