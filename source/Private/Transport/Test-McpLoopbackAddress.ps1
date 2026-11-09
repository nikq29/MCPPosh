function Test-McpLoopbackAddress {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $Address
    )

    $Address.Trim('[', ']') -in 'localhost', '127.0.0.1', '::1'
}
