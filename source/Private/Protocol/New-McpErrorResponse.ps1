function New-McpErrorResponse {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $Id,

        [Parameter(Mandatory)]
        [int] $Code,

        [Parameter(Mandatory)]
        [string] $Message,

        [object] $Data
    )

    $errorObject = [ordered]@{ code = $Code; message = $Message }
    if ($null -ne $Data) { $errorObject['data'] = $Data }
    [ordered]@{ jsonrpc = '2.0'; id = $Id; error = $errorObject }
}
