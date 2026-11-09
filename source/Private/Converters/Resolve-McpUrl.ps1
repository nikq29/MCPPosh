function Resolve-McpUrl {
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
