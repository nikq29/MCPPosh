function Send-McpHttpResponse {
    <#
    .SYNOPSIS
        Writes an HTTP response of the HTTP transport.

    .DESCRIPTION
        Sets the status code, headers (including Cache-Control: no-store and X-Content-Type-Options: nosniff) and the UTF-8 body of an HttpListenerResponse.

    .PARAMETER Response
        The HttpListenerResponse to write to.

    .PARAMETER StatusCode
        The HTTP status code to send, for example 200, 202 or 401.

    .PARAMETER Body
        The response body. An empty body sends Content-Length 0.

    .PARAMETER ContentType
        The Content-Type of the body; JSON with UTF-8 by default.

    .PARAMETER Headers
        Additional response headers such as Allow, WWW-Authenticate or CORS headers.

    .EXAMPLE
        Send-McpHttpResponse -Response $httpContext.Response -StatusCode 405 -Headers @{ Allow = 'POST' }

        Sends 405 Method Not Allowed.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Net.HttpListenerResponse] $Response,

        [Parameter(Mandatory)]
        [int] $StatusCode,

        [AllowEmptyString()]
        [string] $Body = '',

        [string] $ContentType = 'application/json; charset=utf-8',

        [hashtable] $Headers = @{}
    )

    $Response.StatusCode = $StatusCode
    foreach ($header in $Headers.GetEnumerator()) {
        $Response.Headers[$header.Key] = [string]$header.Value
    }
    $Response.Headers['Cache-Control'] = 'no-store'
    $Response.Headers['X-Content-Type-Options'] = 'nosniff'
    if ($Body) {
        $bytes = $script:Utf8NoBom.GetBytes($Body)
        $Response.ContentType = $ContentType
        $Response.ContentLength64 = $bytes.Length
        $Response.OutputStream.Write($bytes, 0, $bytes.Length)
    }
    else {
        $Response.ContentLength64 = 0
    }
}
