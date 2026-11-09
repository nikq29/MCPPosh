function Test-McpLoopbackAddress {
    <#
    .SYNOPSIS
        Tests whether a listen address is a loopback address.

    .DESCRIPTION
        Returns $true for localhost, 127.0.0.1 and ::1 (with or without brackets). Servers on other addresses are reachable from the network and require an API key.

    .PARAMETER Address
        The listen address to check, for example localhost or *.

    .EXAMPLE
        Test-McpLoopbackAddress -Address 'localhost'

        Returns $true.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $Address
    )

    $Address.Trim('[', ']') -in 'localhost', '127.0.0.1', '::1'
}
