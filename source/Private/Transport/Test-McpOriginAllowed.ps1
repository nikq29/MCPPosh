function Test-McpOriginAllowed {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()]
        [string] $Origin,

        [Parameter(Mandatory)]
        [hashtable] $Settings
    )

    if (-not $Origin -or $Origin -eq 'null') { return (-not $Origin) }
    if ($Settings.AllowedOrigins -contains $Origin) { return $true }
    if ($Settings.AllowedOrigins.Count -gt 0) { return $false }
    if ($Settings.IsLoopback) {
        # Protect local servers against DNS rebinding: only local web pages may call them.
        try {
            $originHost = ([uri]$Origin).Host.Trim('[', ']')
            return $originHost -in 'localhost', '127.0.0.1', '::1'
        }
        catch {
            return $false
        }
    }
    $true
}
