function Send-McpHttpResponse {
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
