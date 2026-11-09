function Test-McpOriginAllowed {
    <#
    .SYNOPSIS
        Tests whether a browser origin may call the MCP endpoint.

    .DESCRIPTION
        Allows requests without Origin header and origins listed in AllowedOrigins. Without a list, servers on loopback addresses only accept local origins (protection against DNS rebinding) and other servers accept all origins.

    .PARAMETER Origin
        Value of the Origin header of the request, or $null when it is missing.

    .PARAMETER Settings
        Hashtable with the AllowedOrigins and IsLoopback settings of the server.

    .EXAMPLE
        Test-McpOriginAllowed -Origin 'http://localhost:3000' -Settings @{ AllowedOrigins = @(); IsLoopback = $true }

        Returns $true.
    #>
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
